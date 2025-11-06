SET ROLE app_reader;
DO $$
BEGIN
    RAISE NOTICE '== ПРОВЕРКА ЧТЕНИЯ РАЗРЕШЁННЫХ ТАБЛИЦ ДЛЯ app_reader ==';

    -- Проверка SELECT на таблицах app
    RAISE NOTICE 'Проверка SELECT на app.products';
    BEGIN
        PERFORM * FROM app.products LIMIT 1;
        RAISE NOTICE '? SELECT app.products: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? SELECT app.products: нет прав';
    END;

    -- Проверка SELECT на таблицах ref
    RAISE NOTICE 'Проверка SELECT на ref.product_category';
    BEGIN
        PERFORM * FROM ref.product_category LIMIT 1;
        RAISE NOTICE '? SELECT ref.product_category: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? SELECT ref.product_category: нет прав';
    END;

    -- Проверка SELECT на запрещённых таблицах audit
    RAISE NOTICE 'Проверка SELECT на audit.audit_log';
    BEGIN
        PERFORM * FROM audit.audit_log LIMIT 1;
        RAISE NOTICE '? SELECT audit.audit_log: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? SELECT audit.audit_log: нет прав';
    END;
END $$;
RESET ROLE;

------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE app.test_table_ddl(id INT);
-- Негативный кейс: обычный пользователь
SET ROLE app_reader;
DO $$
BEGIN
	RAISE NOTICE '';
	RAISE NOTICE '';
    RAISE NOTICE '== НЕГАТИВНЫЙ ТЕСТ DDL ДЛЯ app_reader ==';

    BEGIN
        EXECUTE 'CREATE TABLE app.test_table_ddl(id INT)';
        RAISE NOTICE '? CREATE TABLE: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? CREATE TABLE: нет прав';
    END;

    BEGIN
        EXECUTE 'ALTER TABLE app.test_table_ddl ADD COLUMN name TEXT';
        RAISE NOTICE '? ALTER TABLE: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? ALTER TABLE: нет прав';
    END;

    BEGIN
        EXECUTE 'DROP TABLE app.test_table_ddl';
        RAISE NOTICE '? DROP TABLE: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? DROP TABLE: нет прав';
    END;

END $$;
RESET ROLE;
DROP TABLE app.test_table_ddl;

-- Позитивный кейс: DDL админ
SET ROLE ddl_admin;
DO $$
BEGIN
    RAISE NOTICE '== ПОЗИТИВНЫЙ ТЕСТ DDL ДЛЯ ddl_admin ==';

    BEGIN
        EXECUTE 'CREATE TABLE app.test_table_ddl(id INT)';
        RAISE NOTICE '? CREATE TABLE: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? CREATE TABLE: нет прав';
    END;

    BEGIN
        EXECUTE 'ALTER TABLE app.test_table_ddl ADD COLUMN name TEXT';
        RAISE NOTICE '? ALTER TABLE: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? ALTER TABLE: нет прав';
    END;

    BEGIN
        EXECUTE 'DROP TABLE app.test_table_ddl';
        RAISE NOTICE '? DROP TABLE: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? DROP TABLE: нет прав';
    END;

END $$;
RESET ROLE;

------------------------------------------------------------------------------------------------------------------------------------------------

-- Негативный кейс: обычный пользователь
SET ROLE app_reader;
DO $$
BEGIN
	RAISE NOTICE '';
	RAISE NOTICE '';
    RAISE NOTICE '== НЕГАТИВНЫЙ ТЕСТ DML В audit.audit_log ДЛЯ app_reader ==';

    BEGIN
        INSERT INTO audit.audit_log(staff_id, action_time, action_type, action_description, success)
        VALUES (3, now(), 'CREATE', 'TEST DML IN AUDIT', true);
        RAISE NOTICE '? INSERT audit_log: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? INSERT audit_log: нет прав';
    END;

    BEGIN
        UPDATE audit.audit_log
        SET action = 'UPDATED'
        WHERE audit_log_id = 10;
        RAISE NOTICE '? UPDATE audit_log: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? UPDATE audit_log: нет прав';
    END;

    BEGIN
        DELETE FROM audit.audit_log
        WHERE audit_log_id = 10;
        RAISE NOTICE '? DELETE audit_log: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? DELETE audit_log: нет прав';
    END;

END $$;
RESET ROLE;

-- Позитивный кейс: вызов SECURITY DEFINER функции
SET app.current_staff_id = '1';
DO $$
BEGIN
    RAISE NOTICE '== ПОЗИТИВНЫЙ ТЕСТ DML В audit.audit_log с помощью триггера ЧЕРЕЗ SECURITY DEFINER ==';

    BEGIN
        -- Добавим данные в таблицу products
        INSERT INTO app.products (category_id, product_name, price, stock_quantity, article)
        VALUES (1, 'TestProduct', 100, 10, 'ART-TESTDML');
        RAISE NOTICE '? Запись в audit_log создана';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '? Ошибка при создании записи';
    END;

END $$;
ROLLBACK;
RESET ROLE;

------------------------------------------------------------------------------------------------------------------------------------------------

SET ROLE app_reader;
DO $$
DECLARE
    test_order_id INT;
BEGIN
	RAISE NOTICE '';
	RAISE NOTICE '';
	RAISE NOTICE '== ТЕСТ SECURITY DEFINER create_order() ==';

    -- 1. Валидные данные
    BEGIN
		SET client_min_messages = warning;
        test_order_id := app.create_order(
            1,                             -- существующий клиент
            101,                             -- существующая платёжная информация
            'Тестовый адрес', 
            '[{"product_id": 1, "quantity": 2}]'::JSON
        );
		SET client_min_messages = notice;
        RAISE NOTICE '? create_order() с валидными данными прошла, order_id = %', test_order_id;
    EXCEPTION WHEN others THEN
        RAISE NOTICE '? create_order() с валидными данными выбросила ошибку: %', SQLERRM;
    END;

    -- 2. Невалидный клиент
    BEGIN
        test_order_id := app.create_order(
            -1,                            -- несуществующий клиент
            101, 
            'Тестовый адрес', 
            '[{"product_id": 1, "quantity": 2}]'::JSON
        );
        RAISE NOTICE '? create_order() с невалидным клиентом прошла (не должно)';
    EXCEPTION WHEN others THEN
        RAISE NOTICE '? create_order() с невалидным клиентом корректно выбросила ошибку: %', SQLERRM;
    END;

    -- 3. Невалидный товар
    BEGIN
        test_order_id := app.create_order(
            1,
            101,
            'Тестовый адрес',
            '[{"product_id": 999, "quantity": 2}]'::JSON -- несуществующий товар
        );
        RAISE NOTICE '? create_order() с несуществующим товаром прошла (не должно)';
    EXCEPTION WHEN others THEN
        RAISE NOTICE '? create_order() с несуществующим товаром корректно выбросила ошибку: %', SQLERRM;
    END;

    -- 4. Невалидное количество товара
    BEGIN
        test_order_id := app.create_order(
            1,
            101,
            'Тестовый адрес',
            '[{"product_id": 1, "quantity": -5}]'::JSON
        );
        RAISE NOTICE '? create_order() с отрицательным количеством прошла (не должно)';
    EXCEPTION WHEN others THEN
        RAISE NOTICE '? create_order() с отрицательным количеством корректно выбросила ошибку: %', SQLERRM;
    END;

END $$;
ROLLBACK;
RESET ROLE;

SET ROLE app_reader;
DO $$
DECLARE
    test_order_id INT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '';
    RAISE NOTICE '== ТЕСТ SECURITY DEFINER cancel_order() ==';

    -- 1. Валидный заказ, который можно отменить
    BEGIN
        SET client_min_messages = warning;
		test_order_id := app.create_order(
            1,
            101,
            'Тестовый адрес',
            '[{"product_id": 1, "quantity": 2}]'::JSON
        );
		
        PERFORM app.cancel_order(test_order_id);
		SET client_min_messages = notice;
        RAISE NOTICE '? cancel_order() для валидного заказа прошла, order_id = %', test_order_id;
    EXCEPTION WHEN others THEN
        RAISE NOTICE '? cancel_order() для валидного заказа выбросила ошибку: %', SQLERRM;
    END;

    -- 2. Несуществующий заказ
    BEGIN
		PERFORM app.cancel_order(-1);
        RAISE NOTICE '? cancel_order() для несуществующего заказа прошла (не должно)';
    EXCEPTION WHEN others THEN
        RAISE NOTICE '? cancel_order() для несуществующего заказа корректно выбросила ошибку: %', SQLERRM;
    END;

    -- 3. Заказ с неподходящим статусом (например, "Отгружен")
    BEGIN
        SET client_min_messages = warning;
        test_order_id := app.create_order(
            1,
            101,
            'Тестовый адрес',
            '[{"product_id": 1, "quantity": 1}]'::JSON
        );
		SET client_min_messages = notice;

        -- принудительно ставим статус "Отгружен"
        UPDATE app.orders
        SET status = 'Отгружен'
        WHERE order_id = test_order_id;

        PERFORM app.cancel_order(test_order_id);
        RAISE NOTICE '? cancel_order() с неподходящим статусом прошла (не должно)';
    EXCEPTION WHEN others THEN
        RAISE NOTICE '? cancel_order() с неподходящим статусом корректно выбросила ошибку: %', SQLERRM;
    END;

END $$;
ROLLBACK;
RESET ROLE;
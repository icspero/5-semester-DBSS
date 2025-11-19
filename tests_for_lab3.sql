-- Чтение чужих строк, должно быть пусто
DO $$
BEGIN
    SET ROLE user1;
    BEGIN
        PERFORM app.set_session_ctx(2, current_role); -- сегмент 2 не принадлежит user1
        RAISE NOTICE '❌ Ошибка! user1 установил чужой сегмент 2';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ Тест 1: Успешно, доступ к чужому сегменту заблокирован';
    END;
END $$;

DO $$
BEGIN
    SET ROLE user2;
    BEGIN
        PERFORM app.set_session_ctx(1, current_role); -- сегмент 1 не принадлежит user2
        RAISE NOTICE '❌ Ошибка! user2 установил чужой сегмент 1';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ Тест 2: Успешно, доступ к чужому сегменту заблокирован';
    END;
END $$;

-- Вставка с неверным segment_id - ошибка
DO $$
BEGIN
    SET ROLE user1;

    BEGIN
        INSERT INTO app.clients(
            first_name,
            last_name,
            middle_name,
            email,
            phone_number,
            password_hash,
            registration_date,
            date_of_birth,
            status,
            branch_id
        ) VALUES (
            'Тест',          
            'Клиент',       
            'Тестович',      
            'test1@example.com', 
            '79991234567',   
            'hash',       
            now(),         
            '2000-01-01',  
            'Неактивен',    
            2 
        );

        RAISE NOTICE '❌ Ошибка! Вставка в свой сегмент разрешена';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ Тест 3: Вставка запрещена';
    END;
END $$;
DELETE FROM app.clients
WHERE email = 'test1@example.com';

-- Обновление чужого сегмента - ошибка
DO $$
DECLARE
    rows_updated int;
BEGIN
    SET ROLE user1;

    UPDATE app.clients
    SET first_name = 'Попытка'
    WHERE branch_id = 2;

    GET DIAGNOSTICS rows_updated = ROW_COUNT;

    IF rows_updated = 0 THEN
        RAISE NOTICE '✅ Тест 4: Успешно, обновление чужого сегмента запрещено (0 строк обновлено)';
    ELSE
        RAISE NOTICE '❌ Ошибка! user1 обновил чужой сегмент 2 (% строк)', rows_updated;
    END IF;
END $$;

-- Корректные операции в своём сегменте - успешно
DO $$
BEGIN
    SET ROLE user1;

    BEGIN
        INSERT INTO app.clients(
            first_name,
            last_name,
            middle_name,
            email,
            phone_number,
            password_hash,
            registration_date,
            date_of_birth,
            status,
            branch_id
        ) VALUES (
            'Тест',          
            'Клиент',       
            'Тестович',      
            'test1@example.com', 
            '79991234567',   
            'hash',       
            now(),         
            '2000-01-01',  
            'Неактивен',    
            1 
        );

        RAISE NOTICE '✅ Тест 5: Вставка в свой сегмент разрешена';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Ошибка! Вставка запрещена';
    END;
END $$;
DELETE FROM app.clients
WHERE email = 'test1@example.com';

-- Проверка работы set_session_ctx() - успешная установка
DO $$
BEGIN
	SET ROLE user1;
    BEGIN
        PERFORM app.set_session_ctx(1, current_role);
        RAISE NOTICE '✅ Тест 7: Успешно, set_session_ctx() установил сегмент 1 для user1';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Ошибка! user1 не смог установить свой сегмент 1';
    END;
END $$;

-- Проверка set_session_ctx() - ошибка, сегмент не принадлежит роли
DO $$
BEGIN
	SET ROLE user2;
    BEGIN
        PERFORM app.set_session_ctx(3, current_role);
        RAISE NOTICE '❌ Ошибка! user2 установил чужой сегмент 3';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ Тест 7: Успешно, set_session_ctx() запрещает чужой сегмент';
    END;
END $$;

-- Автоматическая подстановка сегмента через current_branch()
SET app.branch_id = '';
DO $$
DECLARE
    seg int;
BEGIN
    SET ROLE user1;
    seg := app.current_branch();  -- должен автоматически выбрать первый сегмент
    RAISE NOTICE '✅ Тест 8: Автоматически выбран сегмент % для user1', seg;
END $$;

-- Проверка RLS для нескольких таблиц
DO $$
DECLARE
    cnt_clients int;
    cnt_orders int;
BEGIN
    SET ROLE user1;
    PERFORM app.set_session_ctx(1, current_role);

    SELECT COUNT(*) INTO cnt_clients FROM app.clients;
    SELECT COUNT(*) INTO cnt_orders  FROM app.orders;

    RAISE NOTICE '✅ Тест 9: user1 видит % клиентов и % заказов', cnt_clients, cnt_orders;
END $$;
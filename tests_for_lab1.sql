SET ROLE app_reader;
DO $$
BEGIN
    RAISE NOTICE '== ПРОВЕРКА РОЛИ app_reader ==';
	RAISE NOTICE 'Проверка SELECT на app.clients';
    BEGIN
        PERFORM * FROM app.clients LIMIT 1;
        RAISE NOTICE '✅ SELECT app.clients: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT app.clients: нет прав';
    END;

    RAISE NOTICE 'Проверка SELECT на app.products';
    BEGIN
        PERFORM * FROM app.products LIMIT 1;
        RAISE NOTICE '✅ SELECT app.products: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT app.products: нет прав';
    END;

    RAISE NOTICE 'Проверка INSERT в app.products';
    BEGIN
        INSERT INTO app.products (category_id, product_name, price, stock_quantity, article)
        VALUES (1, 'TestReader', 100, 1, 'ART-READER');
        RAISE NOTICE '✅ INSERT app.products: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ INSERT app.products: нет прав';
    END;

    RAISE NOTICE 'Проверка UPDATE app.clients';
    BEGIN
        UPDATE app.clients SET first_name = 'Test' WHERE client_id = 1;
        RAISE NOTICE '✅ UPDATE app.clients: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ UPDATE app.clients: нет прав';
    END;

    RAISE NOTICE 'Проверка DELETE app.clients...';
    BEGIN
        DELETE FROM app.clients WHERE client_id = 1;
        RAISE NOTICE '✅ DELETE app.clients: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ DELETE app.clients: нет прав';
    END;
END $$;
RESET ROLE;



SET ROLE app_writer;
DO $$
BEGIN
    RAISE NOTICE '== ПРОВЕРКА РОЛИ app_writer ==';

    RAISE NOTICE 'Проверка SELECT на app.clients';
    BEGIN
        PERFORM * FROM app.clients LIMIT 1;
        RAISE NOTICE '✅ SELECT app.clients: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT app.clients: нет прав';
    END;

    RAISE NOTICE 'Проверка SELECT на ref.product_category';
    BEGIN
        PERFORM * FROM ref.product_category LIMIT 1;
        RAISE NOTICE '✅ SELECT ref.product_category: OK';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT ref.product_category: нет прав';
    END;

    RAISE NOTICE 'Проверка INSERT в app.products';
    BEGIN
        PERFORM 1 FROM pg_class c
        WHERE c.relname='products' AND has_table_privilege('app_writer', 'app.products', 'INSERT');
        RAISE NOTICE '✅ INSERT app.products: роль может вставлять';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ INSERT app.products: нет прав';
    END;

    RAISE NOTICE 'Проверка DELETE из app.clients';
    BEGIN
        PERFORM 1 FROM pg_class c
        WHERE c.relname='clients' AND has_table_privilege('app_writer', 'app.clients', 'DELETE');
        RAISE NOTICE '✅ DELETE app.clients: роль может удалять';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ DELETE app.clients: нет прав';
    END;

    RAISE NOTICE 'Проверка UPDATE app.clients';
    BEGIN
        PERFORM 1 FROM pg_class c
        WHERE c.relname='clients' AND has_table_privilege('app_writer', 'app.clients', 'UPDATE');
        RAISE NOTICE '✅ UPDATE app.clients: роль может обновлять';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ UPDATE app.clients: нет прав';
    END;

END $$;
RESET ROLE;



SET ROLE app_owner;
DO $$
BEGIN
    RAISE NOTICE '== ПРОВЕРКА РОЛИ app_owner ==';

    RAISE NOTICE 'Проверка SELECT на app.clients';
    BEGIN
        PERFORM 1 FROM pg_class c
        WHERE c.relname='clients' AND has_table_privilege('app_owner', 'app.clients', 'SELECT');
        RAISE NOTICE '✅ SELECT app.clients: роль может читать';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT app.clients: нет прав';
    END;

    RAISE NOTICE 'Проверка SELECT на app.products';
    BEGIN
        PERFORM 1 FROM pg_class c
        WHERE c.relname='products' AND has_table_privilege('app_owner', 'app.products', 'SELECT');
        RAISE NOTICE '✅ SELECT app.products: роль может читать';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT app.products: нет прав';
    END;

    RAISE NOTICE 'Проверка INSERT в app.products';
    BEGIN
        PERFORM 1 FROM pg_class c
        WHERE c.relname='products' AND has_table_privilege('app_owner', 'app.products', 'INSERT');
        RAISE NOTICE '✅ INSERT app.products: роль может вставлять';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ INSERT app.products: нет прав';
    END;

    RAISE NOTICE 'Проверка UPDATE app.clients';
    BEGIN
        PERFORM 1 FROM pg_class c
        WHERE c.relname='clients' AND has_table_privilege('app_owner', 'app.clients', 'UPDATE');
        RAISE NOTICE '✅ UPDATE app.clients: роль может обновлять';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ UPDATE app.clients: нет прав';
    END;

    RAISE NOTICE 'Проверка DELETE app.products';
    BEGIN
        PERFORM 1 FROM pg_class c
        WHERE c.relname='products' AND has_table_privilege('app_owner', 'app.products', 'DELETE');
        RAISE NOTICE '✅ DELETE app.products: роль может удалять';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ DELETE app.products: нет прав';
    END;

    RAISE NOTICE 'Проверка CREATE TABLE в схеме app';
    BEGIN
        IF has_schema_privilege('app_owner', 'app', 'CREATE') THEN
            RAISE NOTICE '✅ CREATE TABLE в app: роль может создавать';
        ELSE
            RAISE NOTICE '❌ CREATE TABLE в app: нет прав';
        END IF;
    END;

END $$;
RESET ROLE;



SET ROLE auditor;
DO $$
BEGIN
    RAISE NOTICE '== ПРОВЕРКА РОЛИ auditor ==';

    -- Проверка SELECT на audit.audit_log
    BEGIN
        PERFORM 1 FROM audit.audit_log LIMIT 1;
        RAISE NOTICE '✅ SELECT audit.audit_log: разрешено';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT audit.audit_log: запрещено';
    END;

    -- Проверка INSERT на audit.audit_log
    BEGIN
        INSERT INTO audit.audit_log(staff_id, action_time, action_type, action_description, success)
        VALUES (0, now(), 'OTHER', 'test insert', true);
        RAISE NOTICE '✅ INSERT audit.audit_log: разрешено';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ INSERT audit.audit_log: запрещено';
    END;

    -- Проверка SELECT на app.clients
    BEGIN
        PERFORM 1 FROM app.clients LIMIT 1;
        RAISE NOTICE '✅ SELECT app.clients: разрешено';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT app.clients: запрещено';
    END;

    -- Проверка SELECT на app.products
    BEGIN
        PERFORM 1 FROM app.products LIMIT 1;
        RAISE NOTICE '✅ SELECT app.products: разрешено';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ SELECT app.products: запрещено';
    END;

END $$;
RESET ROLE;



SET ROLE ddl_admin;
DO $$
BEGIN
    RAISE NOTICE '== ПРОВЕРКА РОЛИ ddl_admin ==';

    -- Проверка возможности CREATE TABLE в своей схеме
    RAISE NOTICE 'Проверка CREATE TABLE в stg';
    BEGIN
        PERFORM 1 FROM pg_namespace n
        WHERE n.nspname='stg' AND has_schema_privilege('ddl_admin', 'stg', 'CREATE');
        RAISE NOTICE '✅ CREATE TABLE в stg: роль может создавать объекты';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ CREATE TABLE в stg: нет прав';
    END;

    -- Проверка доступа к схемам
    RAISE NOTICE 'Проверка SELECT на схемы app, ref, audit';
    BEGIN
        PERFORM 1 FROM pg_namespace n
        WHERE n.nspname IN ('app','ref','audit') AND has_schema_privilege('ddl_admin', n.nspname, 'USAGE');
        RAISE NOTICE '✅ Схемы доступны для ddl_admin';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ Нет доступа к схемам';
    END;

    RAISE NOTICE 'Проверка INSERT в app.products';
    BEGIN
		ALTER TABLE app.products DISABLE TRIGGER ALL;
        INSERT INTO app.products(category_id, product_name, price, stock_quantity, article)
        VALUES (1,'Test',100.00,0,'ART-TEST');
        RAISE NOTICE '✅ INSERT app.products: роль может вставлять';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '❌ INSERT app.products: запрещено';
    END;

END $$;
RESET ROLE;
ALTER TABLE app.products ENABLE TRIGGER ALL;



SET ROLE dml_admin;
DO $$
BEGIN
    RAISE NOTICE '== ПРОВЕРКА РОЛИ dml_admin ==';

    -- Проверка SELECT из app.products
    RAISE NOTICE 'Проверка SELECT на app.products';
    RAISE NOTICE '%',
        CASE WHEN has_table_privilege('dml_admin', 'app.products', 'SELECT')
             THEN '✅ SELECT app.products: роль может читать'
             ELSE '❌ SELECT app.products: нет прав'
        END;

    -- Проверка INSERT в app.products
    RAISE NOTICE 'Проверка INSERT в app.products';
    RAISE NOTICE '%',
        CASE WHEN has_table_privilege('dml_admin', 'app.products', 'INSERT')
             THEN '✅ INSERT app.products: роль может вставлять'
             ELSE '❌ INSERT app.products: нет прав'
        END;

    -- Проверка UPDATE в app.products
    RAISE NOTICE 'Проверка UPDATE в app.products';
    RAISE NOTICE '%',
        CASE WHEN has_table_privilege('dml_admin', 'app.products', 'UPDATE')
             THEN '✅ UPDATE app.products: роль может обновлять'
             ELSE '❌ UPDATE app.products: нет прав'
        END;

    -- Проверка DELETE из app.products
    RAISE NOTICE 'Проверка DELETE app.products';
    RAISE NOTICE '%',
        CASE WHEN has_table_privilege('dml_admin', 'app.products', 'DELETE')
             THEN '✅ DELETE app.products: роль может удалять'
             ELSE '❌ DELETE app.products: нет прав'
        END;

    -- Проверка CREATE TABLE в app (безопасно, без создания)
    RAISE NOTICE 'Проверка CREATE TABLE в app';
    RAISE NOTICE '%',
        CASE WHEN has_schema_privilege('dml_admin', 'app', 'CREATE')
             THEN '✅ CREATE TABLE в app: роль может создавать объекты'
             ELSE '❌ CREATE TABLE в app: нет прав'
        END;

END $$;
RESET ROLE;



SET ROLE security_admin;
DO $$
DECLARE
    can_create_role boolean;
BEGIN
    RAISE NOTICE '== ПРОВЕРКА РОЛИ security_admin ==';

    -- Проверка доступа к системным каталогам
    RAISE NOTICE 'Проверка SELECT на pg_roles';
    RAISE NOTICE '%',
        CASE WHEN has_table_privilege('security_admin', 'pg_roles', 'SELECT')
             THEN '✅ SELECT pg_roles: роль может читать'
             ELSE '❌ SELECT pg_roles: нет прав'
        END;

    RAISE NOTICE 'Проверка SELECT на pg_auth_members';
    RAISE NOTICE '%',
        CASE WHEN has_table_privilege('security_admin', 'pg_auth_members', 'SELECT')
             THEN '✅ SELECT pg_auth_members: роль может читать'
             ELSE '❌ SELECT pg_auth_members: нет прав'
        END;

    RAISE NOTICE 'Проверка SELECT на pg_stat_activity';
    RAISE NOTICE '%',
        CASE WHEN has_table_privilege('security_admin', 'pg_stat_activity', 'SELECT')
             THEN '✅ SELECT pg_stat_activity: роль может читать'
             ELSE '❌ SELECT pg_stat_activity: нет прав'
        END;

    RAISE NOTICE 'Проверка SELECT на pg_namespace';
    RAISE NOTICE '%',
        CASE WHEN has_table_privilege('security_admin', 'pg_namespace', 'SELECT')
             THEN '✅ SELECT pg_namespace: роль может читать'
             ELSE '❌ SELECT pg_namespace: нет прав'
        END;
	
    -- Проверка возможности создавать роли
	RAISE NOTICE 'Проверка возможности создавать роли';
    SELECT rolcreaterole INTO can_create_role
    FROM pg_roles
    WHERE rolname = 'security_admin';

    IF can_create_role THEN
        RAISE NOTICE '✅ CREATE ROLE: роль может создавать роли';
    ELSE
        RAISE NOTICE '❌ CREATE ROLE: нет прав';
    END IF;

END $$;
RESET ROLE;

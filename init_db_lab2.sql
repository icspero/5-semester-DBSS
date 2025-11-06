--
-- PostgreSQL database dump
--

\restrict 2koUKPsqLPZ0oRtFd9DjtgvwgfgFhTYl6JbImJOjlKaVq2F14Y5cbedMokvtcVK

-- Dumped from database version 17.6 (Ubuntu 17.6-1.pgdg24.04+1)
-- Dumped by pg_dump version 17.6 (Ubuntu 17.6-1.pgdg24.04+1)

-- Started on 2025-11-06 22:01:14 +07

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 9 (class 2615 OID 16617)
-- Name: app; Type: SCHEMA; Schema: -; Owner: app_owner
--

CREATE SCHEMA app;


ALTER SCHEMA app OWNER TO app_owner;

--
-- TOC entry 13 (class 2615 OID 16619)
-- Name: audit; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA audit;


ALTER SCHEMA audit OWNER TO postgres;

--
-- TOC entry 11 (class 2615 OID 16618)
-- Name: ref; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ref;


ALTER SCHEMA ref OWNER TO postgres;

--
-- TOC entry 12 (class 2615 OID 16620)
-- Name: stg; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA stg;


ALTER SCHEMA stg OWNER TO postgres;

--
-- TOC entry 3 (class 3079 OID 25050)
-- Name: pgaudit; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgaudit WITH SCHEMA public;


--
-- TOC entry 3683 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION pgaudit; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgaudit IS 'provides auditing functionality';


--
-- TOC entry 2 (class 3079 OID 16806)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 3684 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 951 (class 1247 OID 16782)
-- Name: action_type_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.action_type_enum AS ENUM (
    'CREATE',
    'UPDATE',
    'DELETE',
    'OTHER'
);


ALTER TYPE public.action_type_enum OWNER TO postgres;

--
-- TOC entry 918 (class 1247 OID 16622)
-- Name: clients_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.clients_status AS ENUM (
    'Активен',
    'Неактивен',
    'Заблокирован'
);


ALTER TYPE public.clients_status OWNER TO postgres;

--
-- TOC entry 930 (class 1247 OID 16680)
-- Name: order_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.order_status AS ENUM (
    'Создан',
    'Оплачен',
    'В обработке',
    'Отправлен',
    'Доставлен',
    'Отменен'
);


ALTER TYPE public.order_status OWNER TO postgres;

--
-- TOC entry 942 (class 1247 OID 16743)
-- Name: staff_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.staff_role AS ENUM (
    'Менеджер',
    'Администратор',
    'Бухгалтер',
    'Складской'
);


ALTER TYPE public.staff_role OWNER TO postgres;

--
-- TOC entry 299 (class 1255 OID 25145)
-- Name: cancel_order(integer); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.cancel_order(p_order_id integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    current_status order_status;
    item RECORD;
    err_msg TEXT;
BEGIN
    -- Получаем текущий статус заказа
    SELECT status INTO current_status
    FROM app.orders
    WHERE order_id = p_order_id;

    IF NOT FOUND THEN
        err_msg := format('Заказ с id=%s не найден', p_order_id);
        INSERT INTO audit.function_calls(
            function_name, caller_role, input_params, success, error_message
        ) VALUES (
            'cancel_order', current_user,
            'order_id=' || p_order_id,
            FALSE, err_msg
        );
        RETURN;
    END IF;

    -- Проверяем, что заказ можно отменить
    IF current_status NOT IN ('Создан', 'Оплачен') THEN
        err_msg := format('Невозможно отменить заказ со статусом "%s"', current_status);
        INSERT INTO audit.function_calls(
            function_name, caller_role, input_params, success, error_message
        ) VALUES (
            'cancel_order', current_user,
            'order_id=' || p_order_id,
            FALSE, err_msg
        );
        RETURN;
    END IF;

    -- Возвращаем товары на склад
    FOR item IN
        SELECT product_id, COUNT(*) AS qty
        FROM app.order_items
        WHERE order_id = p_order_id
        GROUP BY product_id
    LOOP
        UPDATE app.products
        SET stock_quantity = stock_quantity + item.qty
        WHERE product_id = item.product_id;
    END LOOP;

    -- Устанавливаем статус заказа
    UPDATE app.orders
    SET status = 'Отменен'
    WHERE order_id = p_order_id;

    -- Лог успешного вызова
    INSERT INTO audit.function_calls(
        function_name, caller_role, input_params, success, error_message
    ) VALUES (
        'cancel_order', current_user,
        'order_id=' || p_order_id,
        TRUE, NULL
    );

    RAISE NOTICE 'Заказ % успешно отменён', p_order_id;
END;
$$;


ALTER FUNCTION app.cancel_order(p_order_id integer) OWNER TO postgres;

--
-- TOC entry 286 (class 1255 OID 25206)
-- Name: check_total_amount_trigger(); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.check_total_amount_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF NEW.total_amount < 0 THEN
		RAISE EXCEPTION 'Сумма заказа не может быть отрицательной (%.2f)', NEW.total_amount;
	END IF;
	RETURN NEW;
END;
$$;


ALTER FUNCTION app.check_total_amount_trigger() OWNER TO postgres;

--
-- TOC entry 300 (class 1255 OID 25144)
-- Name: create_order(integer, integer, character varying, json); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.create_order(p_client_id integer, p_payinfo_id integer, p_delivery_address character varying, p_items json) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    new_order_id INT;
    item RECORD;
    product_price NUMERIC;
    current_stock NUMERIC;
    subtotal NUMERIC;
    total_sum NUMERIC := 0;
    client_exists BOOLEAN;
    payinfo_exists BOOLEAN;
    err_msg TEXT;
BEGIN
    -- Проверяем клиента
    SELECT EXISTS (
        SELECT 1 FROM app.clients WHERE client_id = p_client_id
    ) INTO client_exists;

    IF NOT client_exists THEN
        err_msg := format('Клиент с id=%s не найден', p_client_id);
        INSERT INTO audit.function_calls(
            function_name, caller_role, input_params, success, error_message
        ) VALUES (
            'create_order', current_user,
            'client_id=' || p_client_id || ', payinfo_id=' || p_payinfo_id ||
            ', delivery_address=''' || p_delivery_address || '''' ||
            ', items=' || p_items::text,
            FALSE, err_msg
        );
        RETURN NULL;
    END IF;

    -- Проверяем платёжные данные
    SELECT EXISTS (
        SELECT 1 FROM app.payment_information WHERE payinfo_id = p_payinfo_id
    ) INTO payinfo_exists;

    IF NOT payinfo_exists THEN
        err_msg := format('Платёжная информация с id=%s не найдена', p_payinfo_id);
        INSERT INTO audit.function_calls(
            function_name, caller_role, input_params, success, error_message
        ) VALUES (
            'create_order', current_user,
            'client_id=' || p_client_id || ', payinfo_id=' || p_payinfo_id ||
            ', delivery_address=''' || p_delivery_address || '''' ||
            ', items=' || p_items::text,
            FALSE, err_msg
        );
        RETURN NULL;
    END IF;

    -- Создаём заказ
    INSERT INTO app.orders(client_id, payinfo_id, order_date, total_amount, delivery_address)
    VALUES (p_client_id, p_payinfo_id, CURRENT_DATE, 0, p_delivery_address)
    RETURNING order_id INTO new_order_id;

    -- Проходим по товарам из JSON
    FOR item IN
        SELECT * FROM json_to_recordset(p_items) AS (product_id INT, quantity INT)
    LOOP
        SELECT price, stock_quantity INTO product_price, current_stock
        FROM app.products
        WHERE product_id = item.product_id;

        IF NOT FOUND THEN
            err_msg := format('Товар с id=%s не найден', item.product_id);
            INSERT INTO audit.function_calls(
                function_name, caller_role, input_params, success, error_message
            ) VALUES (
                'create_order', current_user,
                'client_id=' || p_client_id || ', payinfo_id=' || p_payinfo_id ||
                ', delivery_address=''' || p_delivery_address || '''' ||
                ', items=' || p_items::text,
                FALSE, err_msg
            );
            RETURN NULL;
        END IF;

        IF item.quantity < 1 THEN
            err_msg := format('Количество для товара %s должно быть >= 1', item.product_id);
            INSERT INTO audit.function_calls(
                function_name, caller_role, input_params, success, error_message
            ) VALUES (
                'create_order', current_user,
                'client_id=' || p_client_id || ', payinfo_id=' || p_payinfo_id ||
                ', delivery_address=''' || p_delivery_address || '''' ||
                ', items=' || p_items::text,
                FALSE, err_msg
            );
            RETURN NULL;
        END IF;

        IF item.quantity > current_stock THEN
            err_msg := format('Недостаточно товара на складе для продукта %s', item.product_id);
            INSERT INTO audit.function_calls(
                function_name, caller_role, input_params, success, error_message
            ) VALUES (
                'create_order', current_user,
                'client_id=' || p_client_id || ', payinfo_id=' || p_payinfo_id ||
                ', delivery_address=''' || p_delivery_address || '''' ||
                ', items=' || p_items::text,
                FALSE, err_msg
            );
            RETURN NULL;
        END IF;

        subtotal := product_price * item.quantity;
        total_sum := total_sum + subtotal;

        INSERT INTO app.order_items(order_id, product_id)
        VALUES (new_order_id, item.product_id);

        UPDATE app.products
        SET stock_quantity = stock_quantity - item.quantity
        WHERE product_id = item.product_id;
    END LOOP;

    -- Обновляем итоговую сумму
    UPDATE app.orders
    SET total_amount = total_sum
    WHERE order_id = new_order_id;

    -- Лог успешного вызова
    INSERT INTO audit.function_calls(
        function_name, caller_role, input_params, success, error_message
    ) VALUES (
        'create_order', current_user,
        'client_id=' || p_client_id || ', payinfo_id=' || p_payinfo_id ||
        ', delivery_address=''' || p_delivery_address || '''' ||
        ', items=' || p_items::text,
        TRUE, NULL
    );

    RETURN new_order_id;
END;
$$;


ALTER FUNCTION app.create_order(p_client_id integer, p_payinfo_id integer, p_delivery_address character varying, p_items json) OWNER TO postgres;

--
-- TOC entry 298 (class 1255 OID 25035)
-- Name: log_action(); Type: FUNCTION; Schema: audit; Owner: postgres
--

CREATE FUNCTION audit.log_action() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'audit', 'public'
    AS $$
DECLARE
    v_action action_type_enum;
    v_staff_id INT;
BEGIN
    -- Пытаемся получить текущего сотрудника, если параметр не задан — NULL
    v_staff_id := current_setting('app.current_staff_id', true)::INT;

    -- Если сотрудник не установлен, просто выходим, не пишем в аудит
    IF v_staff_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Определяем тип действия
    IF TG_OP = 'INSERT' THEN
        v_action := 'CREATE';
    ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'UPDATE';
    ELSIF TG_OP = 'DELETE' THEN
        v_action := 'DELETE';
    ELSE
        v_action := 'OTHER';
    END IF;

    -- Вставляем запись в аудит
    INSERT INTO audit.audit_log (staff_id, action_time, action_type, action_description, success)
    VALUES (v_staff_id, now(), v_action, format('Таблица: %s, действие: %s', TG_TABLE_NAME, TG_OP), TRUE);

    RETURN NULL;
END;
$$;


ALTER FUNCTION audit.log_action() OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 25141)
-- Name: login_audit(); Type: FUNCTION; Schema: audit; Owner: postgres
--

CREATE FUNCTION audit.login_audit() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO audit.login_log(username, client_ip)
    VALUES (session_user, inet_client_addr());
END;
$$;


ALTER FUNCTION audit.login_audit() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 226 (class 1259 OID 16630)
-- Name: clients; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.clients (
    client_id integer NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    middle_name character varying(50),
    email character varying(255) NOT NULL,
    phone_number character varying(20) NOT NULL,
    password_hash text NOT NULL,
    registration_date timestamp without time zone DEFAULT now() NOT NULL,
    date_of_birth date NOT NULL,
    status public.clients_status DEFAULT 'Неактивен'::public.clients_status NOT NULL,
    CONSTRAINT clients_phone_number_check CHECK (((phone_number)::text ~ '^[0-9]{11}$'::text))
);


ALTER TABLE app.clients OWNER TO postgres;

--
-- TOC entry 3688 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE clients; Type: COMMENT; Schema: app; Owner: postgres
--

COMMENT ON TABLE app.clients IS 'Таблица с данными о клиентах';


--
-- TOC entry 225 (class 1259 OID 16629)
-- Name: clients_id_seq; Type: SEQUENCE; Schema: app; Owner: postgres
--

CREATE SEQUENCE app.clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE app.clients_id_seq OWNER TO postgres;

--
-- TOC entry 3690 (class 0 OID 0)
-- Dependencies: 225
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: postgres
--

ALTER SEQUENCE app.clients_id_seq OWNED BY app.clients.client_id;


--
-- TOC entry 239 (class 1259 OID 16766)
-- Name: order_items; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.order_items (
    order_id integer NOT NULL,
    product_id integer NOT NULL
);


ALTER TABLE app.order_items OWNER TO postgres;

--
-- TOC entry 3692 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE order_items; Type: COMMENT; Schema: app; Owner: postgres
--

COMMENT ON TABLE app.order_items IS 'Таблица M:N, чтобы один заказ мог хранить много товаров';


--
-- TOC entry 244 (class 1259 OID 25193)
-- Name: order_items_backup; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.order_items_backup (
    order_id integer,
    product_id integer
);


ALTER TABLE app.order_items_backup OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16694)
-- Name: orders; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.orders (
    order_id integer NOT NULL,
    client_id integer NOT NULL,
    payinfo_id integer NOT NULL,
    order_date date NOT NULL,
    status public.order_status DEFAULT 'Создан'::public.order_status NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    delivery_address character varying(100) NOT NULL,
    date_of_creation timestamp without time zone DEFAULT now(),
    CONSTRAINT chk_total_amount_positive CHECK ((total_amount >= (0)::numeric))
);


ALTER TABLE app.orders OWNER TO postgres;

--
-- TOC entry 3695 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE orders; Type: COMMENT; Schema: app; Owner: postgres
--

COMMENT ON TABLE app.orders IS 'Таблица с заказами';


--
-- TOC entry 243 (class 1259 OID 25190)
-- Name: orders_backup; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.orders_backup (
    order_id integer,
    client_id integer,
    payinfo_id integer,
    order_date date,
    status public.order_status,
    total_amount numeric(10,2),
    delivery_address character varying(100),
    date_of_creation timestamp without time zone
);


ALTER TABLE app.orders_backup OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16693)
-- Name: orders_order_id_seq; Type: SEQUENCE; Schema: app; Owner: postgres
--

CREATE SEQUENCE app.orders_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE app.orders_order_id_seq OWNER TO postgres;

--
-- TOC entry 3698 (class 0 OID 0)
-- Dependencies: 231
-- Name: orders_order_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: postgres
--

ALTER SEQUENCE app.orders_order_id_seq OWNED BY app.orders.order_id;


--
-- TOC entry 230 (class 1259 OID 16658)
-- Name: payment_information; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.payment_information (
    payinfo_id integer NOT NULL,
    client_id integer NOT NULL,
    method_id integer NOT NULL,
    card_number character varying(255),
    card_cvv character varying(255),
    card_expiry date
);


ALTER TABLE app.payment_information OWNER TO postgres;

--
-- TOC entry 3700 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE payment_information; Type: COMMENT; Schema: app; Owner: postgres
--

COMMENT ON TABLE app.payment_information IS 'Таблица с платежными данными клиентов';


--
-- TOC entry 229 (class 1259 OID 16657)
-- Name: payment_information_info_id_seq; Type: SEQUENCE; Schema: app; Owner: postgres
--

CREATE SEQUENCE app.payment_information_info_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE app.payment_information_info_id_seq OWNER TO postgres;

--
-- TOC entry 3702 (class 0 OID 0)
-- Dependencies: 229
-- Name: payment_information_info_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: postgres
--

ALTER SEQUENCE app.payment_information_info_id_seq OWNED BY app.payment_information.payinfo_id;


--
-- TOC entry 236 (class 1259 OID 16725)
-- Name: products; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.products (
    product_id integer NOT NULL,
    category_id integer NOT NULL,
    product_name character varying(100) NOT NULL,
    price numeric(10,2) NOT NULL,
    stock_quantity integer NOT NULL,
    article character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT products_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT products_stock_quantity_check CHECK ((stock_quantity >= 0))
);


ALTER TABLE app.products OWNER TO postgres;

--
-- TOC entry 3704 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE products; Type: COMMENT; Schema: app; Owner: postgres
--

COMMENT ON TABLE app.products IS 'Таблица, которая хранит в себе различные товары';


--
-- TOC entry 235 (class 1259 OID 16724)
-- Name: products_product_id_seq; Type: SEQUENCE; Schema: app; Owner: postgres
--

CREATE SEQUENCE app.products_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE app.products_product_id_seq OWNER TO postgres;

--
-- TOC entry 3706 (class 0 OID 0)
-- Dependencies: 235
-- Name: products_product_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: postgres
--

ALTER SEQUENCE app.products_product_id_seq OWNED BY app.products.product_id;


--
-- TOC entry 238 (class 1259 OID 16752)
-- Name: staff; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.staff (
    staff_id integer NOT NULL,
    username character varying(20) NOT NULL,
    password_hash text NOT NULL,
    email character varying(255) NOT NULL,
    role public.staff_role NOT NULL,
    date_of_creation timestamp without time zone DEFAULT now(),
    is_active boolean DEFAULT true NOT NULL,
    last_name character varying(50) NOT NULL,
    first_name character varying(50) NOT NULL,
    middle_name character varying(50)
);


ALTER TABLE app.staff OWNER TO postgres;

--
-- TOC entry 3708 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE staff; Type: COMMENT; Schema: app; Owner: postgres
--

COMMENT ON TABLE app.staff IS 'Таблица с данными о сотрудниках';


--
-- TOC entry 237 (class 1259 OID 16751)
-- Name: staff_staff_id_seq; Type: SEQUENCE; Schema: app; Owner: postgres
--

CREATE SEQUENCE app.staff_staff_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE app.staff_staff_id_seq OWNER TO postgres;

--
-- TOC entry 3710 (class 0 OID 0)
-- Dependencies: 237
-- Name: staff_staff_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: postgres
--

ALTER SEQUENCE app.staff_staff_id_seq OWNED BY app.staff.staff_id;


--
-- TOC entry 241 (class 1259 OID 16792)
-- Name: audit_log; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.audit_log (
    audit_log_id integer NOT NULL,
    staff_id integer NOT NULL,
    action_time timestamp without time zone DEFAULT now() NOT NULL,
    action_type public.action_type_enum NOT NULL,
    action_description text,
    success boolean NOT NULL
);


ALTER TABLE audit.audit_log OWNER TO postgres;

--
-- TOC entry 3712 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE audit_log; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON TABLE audit.audit_log IS 'Таблица аудита';


--
-- TOC entry 240 (class 1259 OID 16791)
-- Name: audit_log_audit_log_id_seq; Type: SEQUENCE; Schema: audit; Owner: postgres
--

CREATE SEQUENCE audit.audit_log_audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE audit.audit_log_audit_log_id_seq OWNER TO postgres;

--
-- TOC entry 3714 (class 0 OID 0)
-- Dependencies: 240
-- Name: audit_log_audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: postgres
--

ALTER SEQUENCE audit.audit_log_audit_log_id_seq OWNED BY audit.audit_log.audit_log_id;


--
-- TOC entry 246 (class 1259 OID 25220)
-- Name: function_calls; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.function_calls (
    call_id integer NOT NULL,
    call_time timestamp without time zone DEFAULT now(),
    function_name text,
    caller_role text,
    input_params text,
    success boolean,
    error_message text
);


ALTER TABLE audit.function_calls OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 25219)
-- Name: function_calls_call_id_seq; Type: SEQUENCE; Schema: audit; Owner: postgres
--

CREATE SEQUENCE audit.function_calls_call_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE audit.function_calls_call_id_seq OWNER TO postgres;

--
-- TOC entry 3716 (class 0 OID 0)
-- Dependencies: 245
-- Name: function_calls_call_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: postgres
--

ALTER SEQUENCE audit.function_calls_call_id_seq OWNED BY audit.function_calls.call_id;


--
-- TOC entry 242 (class 1259 OID 25134)
-- Name: login_log; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.login_log (
    login_time timestamp without time zone DEFAULT now(),
    username text,
    client_ip inet
);


ALTER TABLE audit.login_log OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 16647)
-- Name: payment_method; Type: TABLE; Schema: ref; Owner: postgres
--

CREATE TABLE ref.payment_method (
    method_id integer NOT NULL,
    method_name character varying(50) NOT NULL,
    description text
);


ALTER TABLE ref.payment_method OWNER TO postgres;

--
-- TOC entry 3722 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE payment_method; Type: COMMENT; Schema: ref; Owner: postgres
--

COMMENT ON TABLE ref.payment_method IS 'Таблица со способами оплаты';


--
-- TOC entry 227 (class 1259 OID 16646)
-- Name: payment_method_method_id_seq; Type: SEQUENCE; Schema: ref; Owner: postgres
--

CREATE SEQUENCE ref.payment_method_method_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.payment_method_method_id_seq OWNER TO postgres;

--
-- TOC entry 3724 (class 0 OID 0)
-- Dependencies: 227
-- Name: payment_method_method_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: postgres
--

ALTER SEQUENCE ref.payment_method_method_id_seq OWNED BY ref.payment_method.method_id;


--
-- TOC entry 234 (class 1259 OID 16714)
-- Name: product_category; Type: TABLE; Schema: ref; Owner: postgres
--

CREATE TABLE ref.product_category (
    category_id integer NOT NULL,
    category_name character varying(50) NOT NULL,
    description text
);


ALTER TABLE ref.product_category OWNER TO postgres;

--
-- TOC entry 3726 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE product_category; Type: COMMENT; Schema: ref; Owner: postgres
--

COMMENT ON TABLE ref.product_category IS 'Таблица с категориями товаров';


--
-- TOC entry 233 (class 1259 OID 16713)
-- Name: product_category_category_id_seq; Type: SEQUENCE; Schema: ref; Owner: postgres
--

CREATE SEQUENCE ref.product_category_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE ref.product_category_category_id_seq OWNER TO postgres;

--
-- TOC entry 3728 (class 0 OID 0)
-- Dependencies: 233
-- Name: product_category_category_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: postgres
--

ALTER SEQUENCE ref.product_category_category_id_seq OWNED BY ref.product_category.category_id;


--
-- TOC entry 3430 (class 2604 OID 16633)
-- Name: clients client_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.clients ALTER COLUMN client_id SET DEFAULT nextval('app.clients_id_seq'::regclass);


--
-- TOC entry 3435 (class 2604 OID 16697)
-- Name: orders order_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.orders ALTER COLUMN order_id SET DEFAULT nextval('app.orders_order_id_seq'::regclass);


--
-- TOC entry 3434 (class 2604 OID 16661)
-- Name: payment_information payinfo_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.payment_information ALTER COLUMN payinfo_id SET DEFAULT nextval('app.payment_information_info_id_seq'::regclass);


--
-- TOC entry 3439 (class 2604 OID 16728)
-- Name: products product_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.products ALTER COLUMN product_id SET DEFAULT nextval('app.products_product_id_seq'::regclass);


--
-- TOC entry 3441 (class 2604 OID 16755)
-- Name: staff staff_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.staff ALTER COLUMN staff_id SET DEFAULT nextval('app.staff_staff_id_seq'::regclass);


--
-- TOC entry 3444 (class 2604 OID 16795)
-- Name: audit_log audit_log_id; Type: DEFAULT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.audit_log ALTER COLUMN audit_log_id SET DEFAULT nextval('audit.audit_log_audit_log_id_seq'::regclass);


--
-- TOC entry 3447 (class 2604 OID 25223)
-- Name: function_calls call_id; Type: DEFAULT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.function_calls ALTER COLUMN call_id SET DEFAULT nextval('audit.function_calls_call_id_seq'::regclass);


--
-- TOC entry 3433 (class 2604 OID 16650)
-- Name: payment_method method_id; Type: DEFAULT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.payment_method ALTER COLUMN method_id SET DEFAULT nextval('ref.payment_method_method_id_seq'::regclass);


--
-- TOC entry 3438 (class 2604 OID 16717)
-- Name: product_category category_id; Type: DEFAULT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.product_category ALTER COLUMN category_id SET DEFAULT nextval('ref.product_category_category_id_seq'::regclass);


--
-- TOC entry 3652 (class 0 OID 16630)
-- Dependencies: 226
-- Data for Name: clients; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.clients (client_id, first_name, last_name, middle_name, email, phone_number, password_hash, registration_date, date_of_birth, status) FROM stdin;
1	Максим	Белополов	Андреевич	maks.belopolov@example.com	79990000001	$2a$06$Hk.GvajSejsOldg4aaDBu.OmGPiyYLY0IOSIaGZ5POpvuok/sbjbm	2025-01-10 09:15:00	1990-05-15	Активен
2	Михаил	Бабаров	Романович	michael.babar@example.com	79990000002	$2a$06$WebTDj4xhNEMsRo6fUANN.eVlumcKybzUP9YkfNzkJBcZtDgr/132	2025-02-05 11:00:00	1988-09-30	Неактивен
3	Максим	Голомёдов	Андреевич	maks.golomedov@example.com	79990000003	$2a$06$osnSEzX8wXqLMkKDrKzRauUt7dQKJcu.zTC/YhfqbA88T9cpKyibS	2025-03-12 14:30:00	1995-02-20	Активен
4	Глеб	Наумов	Александрович	gleb.naumov@example.com	79990000004	$2a$06$pR3aP/EiiHOOUGMgGq5E/uF/4YPHbP8ulvkNmyxYzlJwwOvb3pSyO	2025-04-18 10:45:00	1992-07-07	Активен
5	Екатерина	Мартынова	Дмитриевна	katya.mamamia@example.com	79990000005	$2a$06$W7KbcfjSfu8hP6GZnANjCeqv6r.mpAgM78TyIHbIb5M/btMwO3BAa	2025-05-22 16:20:00	1985-11-11	Заблокирован
6	Сергей	Самойлов	Ярославович	sergey.samoilov@example.com	79990000006	$2a$06$Q8i6YJHQjPfPxDmuSScXMOfsy.WOvEZjN.8DEWN1jYWwLPmUxkrIe	2025-06-02 12:05:00	1998-03-03	Активен
7	Кирилл	Козлов	Владимирович	kirka.kozel@example.com	79990000007	$2a$06$W8ENqYrZOk2IWPYjQfwtvu4k3nOndze59Bm30DGuBUV.cT0GyqUDu	2025-07-09 18:40:00	1991-12-25	Неактивен
8	Даниил	Фролов	Антонович	daniil.frolov@example.com	79990000008	$2a$06$fijZhbsO/hp6fS6wW2.2BO5D68aXeJtRUzdr3QgXFauzHtiL7l97y	2025-08-15 09:00:00	1996-06-06	Активен
9	Даниил	Морозов	Иванович	daniil.morozov@example.com	79990000009	$2a$06$Jfjgq78o56VM/3bIhhkbm.ipQSuzoeQp.jRH.iXbb0pISuhimwh.6	2025-09-01 13:30:00	1989-10-02	Активен
10	Тимур	Габдрахманов	Рамильевич	timur.gab@example.com	79990000010	$2a$06$gb6eLxCWAxdxhIS.qc93quQMnNIY2ktEU3FHLJmZln0wYwi11.uSG	2025-10-20 08:25:00	1993-01-19	Неактивен
\.


--
-- TOC entry 3665 (class 0 OID 16766)
-- Dependencies: 239
-- Data for Name: order_items; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.order_items (order_id, product_id) FROM stdin;
20026	1
20027	1
20028	1
20029	1
20030	1
20031	2
20216	1
20217	2
\.


--
-- TOC entry 3670 (class 0 OID 25193)
-- Dependencies: 244
-- Data for Name: order_items_backup; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.order_items_backup (order_id, product_id) FROM stdin;
1	1
2	2
2	1
3	3
4	5
5	10
6	7
7	8
8	9
9	6
14	1
14	2
\.


--
-- TOC entry 3658 (class 0 OID 16694)
-- Dependencies: 232
-- Data for Name: orders; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.orders (order_id, client_id, payinfo_id, order_date, status, total_amount, delivery_address, date_of_creation) FROM stdin;
20026	1	101	2025-11-06	Создан	119998.00	ул. Ленина, 10	2025-11-06 18:36:37.703473
20027	1	101	2025-11-06	Создан	119998.00	ул. Ленина, 10	2025-11-06 18:38:20.526425
20029	1	101	2025-11-06	Отменен	59999.00	ул. Ленина, 10	2025-11-06 18:53:26.993856
20028	1	101	2025-11-06	Отменен	59999.00	ул. Ленина, 10	2025-11-06 18:44:02.353101
20030	2	101	2025-11-06	Создан	119998.00	ул. Ленина, 10	2025-11-06 19:20:24.308186
20031	1	101	2025-11-06	Отменен	4999.00	ул. Ленина, 10	2025-11-06 19:34:48.741178
20216	1	101	2025-11-06	Создан	119998.00	ул. Ленина, 10	2025-11-06 21:30:47.044957
20217	2	102	2025-11-06	Отменен	4999.00	ул. Ленина, 10	2025-11-06 21:30:47.044957
\.


--
-- TOC entry 3669 (class 0 OID 25190)
-- Dependencies: 243
-- Data for Name: orders_backup; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.orders_backup (order_id, client_id, payinfo_id, order_date, status, total_amount, delivery_address, date_of_creation) FROM stdin;
1	1	101	2025-02-14	Создан	59999.00	Москва, ул. Ленина, д.1	2025-02-14 09:00:00
2	2	102	2025-03-01	Оплачен	14998.00	Москва, пр. Мира, д.2	2025-03-01 10:10:00
3	3	103	2025-04-05	В обработке	1299.00	СПб, ул. Пушкина, д.3	2025-04-05 11:20:00
4	4	104	2025-05-06	Отправлен	1999.00	Казань, ул. Р.Зорге, д.4	2025-05-06 12:30:00
5	5	105	2025-06-10	Доставлен	8999.00	Нижний Новгород, ул. Соборная, д.5	2025-06-10 13:40:00
6	6	106	2025-07-15	Отменен	2499.00	Екатеринбург, ул. Ленина, д.6	2025-07-15 14:50:00
7	7	107	2025-08-20	Создан	29999.00	Новосибирск, ул. Островского, д.7	2025-08-20 15:00:00
8	8	108	2025-09-25	Оплачен	999.00	Воронеж, ул. Советская, д.8	2025-09-25 16:10:00
9	9	109	2025-10-01	Доставлен	599.00	Томск, ул. Кирова, д.9	2025-10-01 17:20:00
10	10	110	2025-10-05	В обработке	1299.00	Курск, ул. Первомайская, д.10	2025-10-05 18:30:00
14	6	106	2025-10-27	Создан	69997.00	Новосибирск, ул. Ленина, д. 10	2025-10-27 23:07:08.794418
\.


--
-- TOC entry 3656 (class 0 OID 16658)
-- Dependencies: 230
-- Data for Name: payment_information; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.payment_information (payinfo_id, client_id, method_id, card_number, card_cvv, card_expiry) FROM stdin;
101	1	1	ww0EBwMCT42DbwhrJSFp0kEBU5QrWWJtA9mlanyp7i1MZJZQjMx0FkNJDTPcIbZoSZde/aZSg6Jj\nuJR3DpM179O3iihTTAOZ6LwDRhPepX9tJQ==	ww0EBwMCjLchitJVbgVy0jQBlRnSQFIbIxOl9h5iqxCYU8dzL+66kDP1OTP4+1RN+SmEbZ4piFXl\nvSTStzggvOukibhJ	2025-11-30
102	2	1	ww0EBwMCeOE7+99AmKx90kEBaBaAOI7Fcz5xQc53NjuA4qqf5P5QJpvzewJdFrxl3JdwlVsyI3ef\nACA+kj8qhcYP2820ka7bCSpLV9yCZWp4zg==	ww0EBwMC7zI2gVLbxVRi0jQBJC8UHu2/4ry4fX3OVQZRN5Om3xayDnBlnJlG2tjQbd9bKPl4y9gz\ndzYq9b80ugncPVrh	2025-08-31
103	3	1	ww0EBwMC3CWfgnxiyUZ50kEB8a6j+3DjdEwcN1PhQ5FL+F5peTPYdoO6NmWYWGmYN3wTUw3cC2V3\nGZyF283Xyz2HXqPR6/0nVp6xTNV4s4C8Tw==	ww0EBwMC9aLOTDRuCU5n0jQBTWAV7zmrYsI5/wprURR2lGBe8PDgRnuza5czUGJbKv2utuG+YXYi\n+LR0OGU6/tAO3Jjl	2025-12-31
104	4	2	\N	\N	\N
105	5	1	ww0EBwMC2eizYXyEydNy0kEBT6R7BXwSJVz31ojKis6DuuXky1AaZxPEy1bO8e+k9ixb17qXCA2M\nUG2wDFIf2iy3LgjNNkmRi316W2lepMmGRw==	ww0EBwMC22TbkxGcBP5+0jQBAVSbcp5koe46o5390WMCxpjjvpzfbTikxm3HVg6+5U2BrP66sETQ\nD8kuVfBvSSxyldDK	2025-07-31
106	6	1	ww0EBwMC7z4KooW4TAZn0kEBSFJj3MBaQzRULXAlmRm9nAMNj3bzzsqBJ9am/jkaEri/fCuHxt6b\nVIEJ1SwyrH2J0m1aKe2Xs1O0yRtL2wXCsA==	ww0EBwMCXkboeX4Obdd90jQBaKN4tC8bm03SYZZaKIKFl5Ddnsnz6A06B0V1lVePKGigj+sbcgXA\nW44Hk+TERPPK25nj	2026-01-31
107	7	2	\N	\N	\N
108	8	1	ww0EBwMCWA+rmf7cRqxq0kEBQV4+f444sOt2d7PMYNih+4TbAXQphmhRdcZ3g00XbAdvnLr+ybSt\nWH1xHalgpVftPUM2we5JNr6NtLe3Lb6s9A==	ww0EBwMCKTXlKN/ZJ8190jQBQX3bFIMwTf4nxCTQHw4j3aUjI0bRdbiJozrO6H7F4fyo9vbnO5Qx\nA5PqrDs1nwk5BQ3S	2025-09-30
109	9	1	ww0EBwMChdYLJsQsUvtk0kEBAr47qjWKeHSZy7ojywWaRa0wFoHoaZe5kXLPf/drjGSJ/2v+D6sA\nSNqApA1Y6Kpf41IqwXI3jw4FRhLVoqw1Jg==	ww0EBwMCNsfcYPGvRvhl0jQBUEZpOoaLeAuf8MhqaXXaxx8IoTilrR0NDuodJxbVW6u10OqZaBY8\n0qUj7FtcrTGxbufW	2025-10-31
110	10	1	ww0EBwMCEg70/Fr1WHpg0kEBEVe6c5aPakYTPBYPeqJF0h3SBcaVNA/wREX9yvcxwWfJCMvvL8OQ\nT2k2upuBm8o/N0VtmugD/UN7cZMaWYUQNQ==	ww0EBwMCNIYfHzndxLti0jQBFwEtu9WzJbbQsGOLdW/A9zHkOOSj56CZY4nJ4izztilhCVpeGkbJ\n082QaEwS3dyJ/uNO	2025-06-30
\.


--
-- TOC entry 3662 (class 0 OID 16725)
-- Dependencies: 236
-- Data for Name: products; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.products (product_id, category_id, product_name, price, stock_quantity, article, is_active) FROM stdin;
3	2	Книга: Алгоритмы	1299.00	30	ART-BK-0001	t
4	3	Футболка Стетхэм	799.00	100	ART-CL-0001	t
5	4	Светильник	1999.00	20	ART-HH-0001	t
6	5	Крем увлажняющий	599.00	40	ART-CM-0001	t
7	6	Гантели 5кг	2499.00	25	ART-SP-0001	t
8	1	iPad	29999.00	10	ART-EL-0003	t
9	2	Книга: SQL для профи	999.00	12	ART-BK-0002	t
10	3	Куртка зимняя	8999.00	8	ART-CL-0002	t
11	1	MacBook Pro	450000.00	7	ART-EL-0008	t
1	1	iPhone 99	59999.00	6	ART-EL-0001	t
2	1	Air Pods 10	4999.00	48	ART-EL-0002	t
\.


--
-- TOC entry 3664 (class 0 OID 16752)
-- Dependencies: 238
-- Data for Name: staff; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.staff (staff_id, username, password_hash, email, role, date_of_creation, is_active, last_name, first_name, middle_name) FROM stdin;
1	manager1	$2a$06$YFfHkZO3A8JGRh8yygiFaucT1AvFhn0jr/55PjXJLJ.vDJOUEyPbW	mgr1@example.com	Менеджер	2025-01-05 09:00:00	t	Иванов	Иван	Иванович
2	admin	$2a$06$vkfZ951mB5fcxCGiROjPze6f4WVBOef9pr/wmv/4zx/OUhPOvhHDq	admin@example.com	Администратор	2025-01-06 09:30:00	t	Морозова	Мария	Анатольевна
3	manager2	$2a$06$mWCdT7b.8N9Os6KPbj1kvuCKwOAmoB5zkAGOgarYb3ZAACWELthUO	mgr21@example.com	Бухгалтер	2025-02-02 10:00:00	t	Баранов	Алексей	Климович
4	stock1	$2a$06$v9ZSrHpjG6bKe.0zUdMvc.VaxAogZiFkr5EVhkp6BTqJOu/YXdUbG	stock1@example.com	Складской	2025-02-10 11:15:00	t	Александров	Пётр	Евгеньевич
5	manager3	$2a$06$hH8daHZLo2oIW83.HYw/Gu/BnurUHBZ5W83BfVLdEI7iGTwhrOXfG	mgr3@example.com	Менеджер	2025-03-12 12:00:00	t	Плотникова	Ольга	Сергеевна
6	staff6	$2a$06$0Qn7Akw0blfo/TEi08u.LujWoAuP4SsnVR0vHkE86UZG2lmF0XhZy	staff6@example.com	Складской	2025-03-20 13:10:00	t	Слемзин	Сергей	Владимирович
7	staff7	$2a$06$05kxYRCWqudIEfFyjDjj7.1Do7UfTLJYTDZsJad2wTMUno6/XOtqa	staff7@example.com	Бухгалтер	2025-04-01 14:20:00	t	Брит	Елена	Алексеевна
8	staff8	$2a$06$tF3XGHOOASwtUYil4M95Wu5EQi8q.QwdEpjz2YiZ/xnTHKubUQGzG	staff8@example.com	Менеджер	2025-04-15 15:30:00	t	Мартынов	Дмитрий	Егорович
9	staff9	$2a$06$fYuhsSUXA9HXmOp4ObRLyOIYoB6Cq2r3C/5fg7QnLXj9EHHUeLeSi	staff9@example.com	Администратор	2025-05-01 16:40:00	t	Федорова	Наталья	Афанасьевна
10	staff10	$2a$06$EytOfTmjg9OksYf0flFIV.PYCn1l3hTtUHHbllACXXPEKUADaDtUG	staff10@example.com	Складской	2025-05-10 17:50:00	t	Самойлов	Игорь	Сергеевич
\.


--
-- TOC entry 3667 (class 0 OID 16792)
-- Dependencies: 241
-- Data for Name: audit_log; Type: TABLE DATA; Schema: audit; Owner: postgres
--

COPY audit.audit_log (audit_log_id, staff_id, action_time, action_type, action_description, success) FROM stdin;
1	1	2025-01-11 09:10:00	CREATE	Создан профиль клиента 1	t
2	2	2025-01-12 10:20:00	UPDATE	Обновлён курс обмена	t
3	3	2025-02-15 11:30:00	DELETE	Удалён тестовый объект	f
4	1	2025-03-01 12:40:00	UPDATE	Изменение статуса заказа #2	t
5	4	2025-04-02 13:50:00	CREATE	Добавлен товар ART-EL-0003	t
6	5	2025-05-03 14:00:00	OTHER	Выполнение служебной операции	t
7	6	2025-06-04 15:10:00	CREATE	Создан складской отчёт	t
8	7	2025-07-05 16:20:00	UPDATE	Подправлены цены	t
9	8	2025-08-06 17:30:00	DELETE	Удаление дубликата	t
10	9	2025-09-07 18:40:00	OTHER	Тестовая запись аудита	t
11	2	2025-10-18 17:49:05.637612	CREATE	Таблица: products, действие: INSERT	t
22	1	2025-10-27 16:38:49.863465	UPDATE	Таблица: staff, действие: UPDATE	t
26	1	2025-10-27 23:07:08.794418	CREATE	Таблица: orders, действие: INSERT	t
27	1	2025-10-27 23:07:08.794418	UPDATE	Таблица: products, действие: UPDATE	t
28	1	2025-10-27 23:07:08.794418	UPDATE	Таблица: products, действие: UPDATE	t
29	1	2025-10-27 23:07:08.794418	UPDATE	Таблица: orders, действие: UPDATE	t
40	1	2025-11-06 00:26:57.180453	CREATE	Таблица: products, действие: INSERT	t
\.


--
-- TOC entry 3672 (class 0 OID 25220)
-- Dependencies: 246
-- Data for Name: function_calls; Type: TABLE DATA; Schema: audit; Owner: postgres
--

COPY audit.function_calls (call_id, call_time, function_name, caller_role, input_params, success, error_message) FROM stdin;
16	2025-11-06 18:56:41.379959	create_order	postgres	client_id=-1, payinfo_id=101, delivery_address='ул. Ленина, 10', items=[{"product_id": 1, "quantity": 2}]	f	Клиент с id=-1 не найден
17	2025-11-06 18:59:46.98249	cancel_order	postgres	order_id=20029	t	\N
18	2025-11-06 19:00:44.621615	cancel_order	postgres	order_id=20028	t	\N
19	2025-11-06 19:01:03.259567	cancel_order	postgres	order_id=20030	f	Заказ с id=20030 не найден
20	2025-11-06 19:42:49.443916	cancel_order	postgres	order_id=20031	t	\N
21	2025-11-06 19:48:42.822339	cancel_order	postgres	order_id=20031	f	Невозможно отменить заказ со статусом "Отменен"
22	2025-11-06 19:48:44.800442	cancel_order	postgres	order_id=20031	f	Невозможно отменить заказ со статусом "Отменен"
23	2025-11-06 19:48:48.252025	cancel_order	postgres	order_id=20032	f	Заказ с id=20032 не найден
24	2025-11-06 19:48:51.524688	cancel_order	postgres	order_id=20033	f	Заказ с id=20033 не найден
25	2025-11-06 19:48:58.238481	cancel_order	postgres	order_id=20033	f	Заказ с id=20033 не найден
26	2025-11-06 19:48:59.720609	cancel_order	postgres	order_id=20033	f	Заказ с id=20033 не найден
27	2025-11-06 19:49:00.28632	cancel_order	postgres	order_id=20033	f	Заказ с id=20033 не найден
28	2025-11-06 19:49:00.713912	cancel_order	postgres	order_id=20033	f	Заказ с id=20033 не найден
29	2025-11-06 19:49:06.290025	cancel_order	postgres	order_id=21	f	Заказ с id=21 не найден
30	2025-11-06 19:49:06.86298	cancel_order	postgres	order_id=21	f	Заказ с id=21 не найден
31	2025-11-06 19:49:10.290846	cancel_order	postgres	order_id=4000	f	Заказ с id=4000 не найден
32	2025-11-06 19:49:15.757406	cancel_order	postgres	order_id=100000000	f	Заказ с id=100000000 не найден
33	2025-11-06 21:30:47.044957	create_order	postgres	client_id=1, payinfo_id=101, delivery_address='ул. Ленина, 10', items=[{"product_id": 1, "quantity": 2}]	t	\N
34	2025-11-06 21:30:47.044957	create_order	postgres	client_id=2, payinfo_id=102, delivery_address='ул. Ленина, 10', items=[{"product_id": 2, "quantity": 1}]	t	\N
35	2025-11-06 21:30:47.044957	create_order	postgres	client_id=-2, payinfo_id=102, delivery_address='ул. Ленина, 10', items=[{"product_id": 3, "quantity": 4}]	f	Клиент с id=-2 не найден
36	2025-11-06 21:34:51.856675	cancel_order	postgres	order_id=20217	t	\N
37	2025-11-06 21:34:51.856675	cancel_order	postgres	order_id=20217	f	Невозможно отменить заказ со статусом "Отменен"
38	2025-11-06 21:34:51.856675	cancel_order	postgres	order_id=923649827	f	Заказ с id=923649827 не найден
\.


--
-- TOC entry 3668 (class 0 OID 25134)
-- Dependencies: 242
-- Data for Name: login_log; Type: TABLE DATA; Schema: audit; Owner: postgres
--

COPY audit.login_log (login_time, username, client_ip) FROM stdin;
2025-10-20 14:26:12.530949	postgres	127.0.0.1
2025-10-20 14:35:00.631142	postgres	127.0.0.1
2025-10-20 14:35:00.631375	postgres	127.0.0.1
2025-10-20 14:35:06.855093	postgres	127.0.0.1
2025-10-20 14:35:36.162779	postgres	127.0.0.1
2025-10-20 14:36:34.528955	postgres	127.0.0.1
2025-10-20 14:36:34.53649	postgres	127.0.0.1
2025-10-20 14:36:39.01081	postgres	127.0.0.1
2025-10-20 14:36:56.009513	test_for_login_log	\N
2025-10-20 14:37:03.006108	test_for_login_log	\N
2025-10-20 14:37:15.969653	postgres	127.0.0.1
2025-10-20 14:37:17.472437	postgres	127.0.0.1
2025-10-20 14:37:17.477217	postgres	127.0.0.1
2025-10-20 14:37:30.909886	postgres	127.0.0.1
2025-10-20 14:53:55.061359	postgres	127.0.0.1
2025-10-20 14:54:29.323477	postgres	127.0.0.1
2025-10-20 14:54:37.992941	postgres	127.0.0.1
2025-10-20 14:54:46.085293	postgres	127.0.0.1
2025-10-20 14:59:21.239529	postgres	127.0.0.1
2025-10-20 15:12:58.164752	postgres	127.0.0.1
2025-10-20 15:13:02.747906	postgres	127.0.0.1
2025-10-20 15:24:04.162553	postgres	127.0.0.1
2025-10-20 15:24:10.519921	postgres	127.0.0.1
2025-10-20 15:25:04.062887	postgres	127.0.0.1
2025-10-20 15:25:16.286456	postgres	127.0.0.1
2025-10-20 15:30:50.814579	postgres	127.0.0.1
2025-10-20 15:38:24.517565	postgres	127.0.0.1
2025-10-20 15:43:32.809968	postgres	127.0.0.1
2025-10-20 15:43:35.533588	postgres	127.0.0.1
2025-10-20 15:44:08.569745	postgres	127.0.0.1
2025-10-20 15:50:59.603163	postgres	127.0.0.1
2025-10-20 15:54:47.340167	postgres	127.0.0.1
2025-10-20 15:54:48.794472	postgres	127.0.0.1
2025-10-20 15:54:50.131536	postgres	127.0.0.1
2025-10-20 16:06:29.876456	postgres	127.0.0.1
2025-10-20 16:12:09.596012	postgres	127.0.0.1
2025-10-20 16:12:13.545914	postgres	127.0.0.1
2025-10-20 16:12:18.817661	postgres	127.0.0.1
2025-10-20 16:17:26.047941	postgres	127.0.0.1
2025-10-20 16:34:30.642163	postgres	127.0.0.1
2025-10-24 21:31:20.055	postgres	127.0.0.1
2025-10-24 21:31:20.053882	postgres	127.0.0.1
2025-10-24 21:34:52.437877	postgres	127.0.0.1
2025-10-24 21:34:53.811962	postgres	127.0.0.1
2025-10-24 21:35:02.788388	postgres	127.0.0.1
2025-10-24 21:38:12.558596	postgres	127.0.0.1
2025-10-24 21:38:19.422998	postgres	127.0.0.1
2025-10-24 21:38:20.565566	postgres	127.0.0.1
2025-10-24 21:47:00.31498	postgres	127.0.0.1
2025-10-24 21:50:26.985918	postgres	127.0.0.1
2025-10-24 23:21:26.939849	postgres	127.0.0.1
2025-10-24 23:21:32.897291	postgres	127.0.0.1
2025-10-24 23:42:35.130641	postgres	127.0.0.1
2025-10-24 23:42:37.276948	postgres	127.0.0.1
2025-10-24 23:42:38.731032	postgres	127.0.0.1
2025-10-24 23:42:39.736442	postgres	127.0.0.1
2025-10-24 23:42:41.899685	postgres	127.0.0.1
2025-10-24 23:42:44.157445	postgres	127.0.0.1
2025-10-27 15:55:03.25898	postgres	127.0.0.1
2025-10-27 15:55:03.263155	postgres	127.0.0.1
2025-10-27 15:56:29.385462	postgres	127.0.0.1
2025-10-27 15:56:46.837866	postgres	127.0.0.1
2025-10-27 16:21:08.520306	postgres	127.0.0.1
2025-10-27 16:30:34.932327	postgres	127.0.0.1
2025-10-27 16:39:11.572385	postgres	127.0.0.1
2025-10-27 16:39:29.908106	postgres	127.0.0.1
2025-10-27 16:40:24.201784	postgres	127.0.0.1
2025-10-27 16:40:44.543313	postgres	127.0.0.1
2025-10-27 16:41:20.262657	postgres	127.0.0.1
2025-10-27 16:41:28.289994	postgres	127.0.0.1
2025-10-27 16:41:29.420757	postgres	127.0.0.1
2025-10-27 16:41:35.153704	postgres	127.0.0.1
2025-10-27 16:42:10.019539	postgres	127.0.0.1
2025-10-27 16:43:04.126502	postgres	127.0.0.1
2025-10-27 16:57:27.113549	postgres	127.0.0.1
2025-10-27 16:57:33.369299	postgres	127.0.0.1
2025-10-27 16:58:27.375878	postgres	127.0.0.1
2025-10-27 17:23:52.965594	postgres	127.0.0.1
2025-10-27 18:03:31.059193	postgres	127.0.0.1
2025-10-27 22:31:09.298013	postgres	127.0.0.1
2025-10-27 22:37:00.98894	postgres	127.0.0.1
2025-10-27 22:42:32.836896	postgres	127.0.0.1
2025-10-27 22:43:35.438674	postgres	127.0.0.1
2025-10-27 22:47:42.193375	postgres	127.0.0.1
2025-10-27 22:49:06.164553	postgres	127.0.0.1
2025-10-27 22:51:12.174305	postgres	127.0.0.1
2025-10-27 22:51:13.650305	postgres	127.0.0.1
2025-10-27 22:51:14.460886	postgres	127.0.0.1
2025-10-27 22:51:15.307703	postgres	127.0.0.1
2025-10-27 22:51:16.331031	postgres	127.0.0.1
2025-10-27 22:51:18.928404	postgres	127.0.0.1
2025-10-27 22:52:04.815223	postgres	127.0.0.1
2025-10-27 22:52:14.407275	postgres	127.0.0.1
2025-10-27 22:52:24.018087	postgres	127.0.0.1
2025-10-27 22:52:48.484022	postgres	127.0.0.1
2025-10-27 22:54:16.462858	postgres	127.0.0.1
2025-10-27 22:55:13.516632	postgres	127.0.0.1
2025-10-27 23:04:26.937763	postgres	127.0.0.1
2025-10-27 23:04:31.411253	postgres	127.0.0.1
2025-10-27 23:07:18.358362	postgres	127.0.0.1
2025-10-27 23:07:44.713841	postgres	127.0.0.1
2025-10-27 23:08:11.142968	postgres	127.0.0.1
2025-10-27 23:08:19.962534	postgres	127.0.0.1
2025-10-27 23:08:27.047258	postgres	127.0.0.1
2025-10-27 23:08:47.702844	postgres	127.0.0.1
2025-10-27 23:08:48.322134	postgres	127.0.0.1
2025-10-27 23:08:48.783657	postgres	127.0.0.1
2025-10-27 23:08:49.283507	postgres	127.0.0.1
2025-10-27 23:08:49.634278	postgres	127.0.0.1
2025-10-27 23:08:50.07272	postgres	127.0.0.1
2025-10-27 23:08:50.438943	postgres	127.0.0.1
2025-10-27 23:08:52.815379	postgres	127.0.0.1
2025-10-27 23:32:54.819562	postgres	127.0.0.1
2025-10-27 23:34:05.63347	postgres	127.0.0.1
2025-10-28 00:02:55.723953	postgres	127.0.0.1
2025-10-29 18:00:02.349415	postgres	127.0.0.1
2025-10-29 18:00:03.018559	postgres	127.0.0.1
2025-10-29 18:00:03.299571	postgres	127.0.0.1
2025-10-29 18:00:03.327669	postgres	127.0.0.1
2025-10-29 18:02:16.305803	postgres	127.0.0.1
2025-10-29 18:02:16.30704	postgres	127.0.0.1
2025-11-05 21:24:58.610442	postgres	127.0.0.1
2025-11-05 21:24:58.82833	postgres	127.0.0.1
2025-11-05 21:25:00.235951	postgres	127.0.0.1
2025-11-05 21:25:00.236655	postgres	127.0.0.1
2025-11-05 23:33:33.868185	postgres	127.0.0.1
2025-11-05 23:33:33.875075	postgres	127.0.0.1
2025-11-05 23:41:43.965588	postgres	127.0.0.1
2025-11-06 00:11:19.057651	postgres	127.0.0.1
2025-11-06 00:19:24.205996	postgres	127.0.0.1
2025-11-06 00:21:29.694195	postgres	127.0.0.1
2025-11-06 00:27:46.9217	postgres	127.0.0.1
2025-11-06 00:27:49.147168	postgres	127.0.0.1
2025-11-06 00:34:47.080059	postgres	127.0.0.1
2025-11-06 00:34:48.964646	postgres	127.0.0.1
2025-11-06 00:36:07.11628	postgres	127.0.0.1
2025-11-06 00:36:07.77878	postgres	127.0.0.1
2025-11-06 00:52:27.18267	postgres	127.0.0.1
2025-11-06 02:50:09.819583	postgres	127.0.0.1
2025-11-06 02:50:09.945138	postgres	127.0.0.1
2025-11-06 02:50:10.14422	postgres	127.0.0.1
2025-11-06 02:50:10.168275	postgres	127.0.0.1
2025-11-06 02:50:10.317032	postgres	127.0.0.1
2025-11-06 02:50:10.698401	postgres	127.0.0.1
2025-11-06 02:50:24.05425	postgres	127.0.0.1
2025-11-06 02:50:24.053907	postgres	127.0.0.1
2025-11-06 02:50:59.052843	postgres	127.0.0.1
2025-11-06 03:19:12.259625	postgres	127.0.0.1
2025-11-06 03:19:16.175597	postgres	127.0.0.1
2025-11-06 03:26:41.405901	postgres	127.0.0.1
2025-11-06 03:26:41.806814	postgres	127.0.0.1
2025-11-06 03:26:49.704732	postgres	127.0.0.1
2025-11-06 03:27:34.058247	postgres	127.0.0.1
2025-11-06 03:29:05.36971	postgres	127.0.0.1
2025-11-06 03:29:08.918639	postgres	127.0.0.1
2025-11-06 03:31:25.340329	postgres	127.0.0.1
2025-11-06 03:31:28.023627	postgres	127.0.0.1
2025-11-06 03:31:31.980867	postgres	127.0.0.1
2025-11-06 03:31:35.383201	postgres	127.0.0.1
2025-11-06 03:38:33.187772	postgres	127.0.0.1
2025-11-06 03:38:53.124108	postgres	127.0.0.1
2025-11-06 03:39:11.609582	postgres	127.0.0.1
2025-11-06 03:40:47.116601	postgres	127.0.0.1
2025-11-06 03:42:11.705976	postgres	127.0.0.1
2025-11-06 03:48:01.898797	postgres	127.0.0.1
2025-11-06 03:48:03.847374	postgres	127.0.0.1
2025-11-06 03:48:05.533639	postgres	127.0.0.1
2025-11-06 03:54:10.59232	postgres	127.0.0.1
2025-11-06 16:00:25.286433	postgres	127.0.0.1
2025-11-06 16:00:25.285332	postgres	127.0.0.1
2025-11-06 18:08:37.729544	postgres	127.0.0.1
2025-11-06 18:20:39.34338	postgres	127.0.0.1
2025-11-06 18:20:39.344523	postgres	127.0.0.1
2025-11-06 18:22:50.056343	postgres	127.0.0.1
2025-11-06 18:35:19.154498	postgres	127.0.0.1
2025-11-06 18:36:01.549416	postgres	127.0.0.1
2025-11-06 18:51:18.538887	postgres	127.0.0.1
2025-11-06 19:00:18.486374	postgres	127.0.0.1
2025-11-06 19:00:31.788369	postgres	127.0.0.1
2025-11-06 19:13:22.548865	postgres	127.0.0.1
2025-11-06 20:49:55.415486	postgres	127.0.0.1
2025-11-06 20:49:55.435193	postgres	127.0.0.1
2025-11-06 20:49:55.603885	postgres	127.0.0.1
2025-11-06 20:49:55.735885	postgres	127.0.0.1
2025-11-06 20:49:55.851222	postgres	127.0.0.1
2025-11-06 20:49:55.989325	postgres	127.0.0.1
2025-11-06 20:49:59.23737	postgres	127.0.0.1
2025-11-06 20:49:59.237621	postgres	127.0.0.1
2025-11-06 20:50:52.198778	postgres	127.0.0.1
2025-11-06 21:03:29.969886	postgres	127.0.0.1
2025-11-06 21:03:42.20636	postgres	127.0.0.1
2025-11-06 21:19:54.30384	postgres	127.0.0.1
2025-11-06 21:28:29.324642	postgres	127.0.0.1
2025-11-06 21:28:29.59471	postgres	127.0.0.1
2025-11-06 21:28:29.616834	postgres	127.0.0.1
2025-11-06 21:28:33.19025	postgres	127.0.0.1
2025-11-06 21:28:33.195712	postgres	127.0.0.1
2025-11-06 21:30:47.028499	postgres	127.0.0.1
2025-11-06 21:31:54.326479	postgres	127.0.0.1
2025-11-06 21:33:00.134335	postgres	127.0.0.1
2025-11-06 21:48:27.299646	postgres	127.0.0.1
2025-11-06 21:48:28.267767	postgres	127.0.0.1
2025-11-06 21:48:29.306946	postgres	127.0.0.1
2025-11-06 22:00:10.808634	postgres	127.0.0.1
2025-11-06 22:01:14.943874	postgres	127.0.0.1
\.


--
-- TOC entry 3654 (class 0 OID 16647)
-- Dependencies: 228
-- Data for Name: payment_method; Type: TABLE DATA; Schema: ref; Owner: postgres
--

COPY ref.payment_method (method_id, method_name, description) FROM stdin;
1	Карта	Оплата картой
2	Наличные	Оплата наличными
\.


--
-- TOC entry 3660 (class 0 OID 16714)
-- Dependencies: 234
-- Data for Name: product_category; Type: TABLE DATA; Schema: ref; Owner: postgres
--

COPY ref.product_category (category_id, category_name, description) FROM stdin;
1	Электроника	Гаджеты и электроника
2	Книги	Книги и учебники
3	Одежда	Мужская и женская одежда
4	Дом и сад	Товары для дома
5	Косметика	Косметические средства
6	Спорт	Товары для спорта
\.


--
-- TOC entry 3730 (class 0 OID 0)
-- Dependencies: 225
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.clients_id_seq', 1, false);


--
-- TOC entry 3731 (class 0 OID 0)
-- Dependencies: 231
-- Name: orders_order_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.orders_order_id_seq', 20217, true);


--
-- TOC entry 3732 (class 0 OID 0)
-- Dependencies: 229
-- Name: payment_information_info_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.payment_information_info_id_seq', 1, false);


--
-- TOC entry 3733 (class 0 OID 0)
-- Dependencies: 235
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.products_product_id_seq', 39, true);


--
-- TOC entry 3734 (class 0 OID 0)
-- Dependencies: 237
-- Name: staff_staff_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.staff_staff_id_seq', 1, false);


--
-- TOC entry 3735 (class 0 OID 0)
-- Dependencies: 240
-- Name: audit_log_audit_log_id_seq; Type: SEQUENCE SET; Schema: audit; Owner: postgres
--

SELECT pg_catalog.setval('audit.audit_log_audit_log_id_seq', 79, true);


--
-- TOC entry 3736 (class 0 OID 0)
-- Dependencies: 245
-- Name: function_calls_call_id_seq; Type: SEQUENCE SET; Schema: audit; Owner: postgres
--

SELECT pg_catalog.setval('audit.function_calls_call_id_seq', 38, true);


--
-- TOC entry 3737 (class 0 OID 0)
-- Dependencies: 227
-- Name: payment_method_method_id_seq; Type: SEQUENCE SET; Schema: ref; Owner: postgres
--

SELECT pg_catalog.setval('ref.payment_method_method_id_seq', 1, false);


--
-- TOC entry 3738 (class 0 OID 0)
-- Dependencies: 233
-- Name: product_category_category_id_seq; Type: SEQUENCE SET; Schema: ref; Owner: postgres
--

SELECT pg_catalog.setval('ref.product_category_category_id_seq', 1, false);


--
-- TOC entry 3454 (class 2606 OID 16642)
-- Name: clients clients_email_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.clients
    ADD CONSTRAINT clients_email_key UNIQUE (email);


--
-- TOC entry 3456 (class 2606 OID 16644)
-- Name: clients clients_phone_number_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.clients
    ADD CONSTRAINT clients_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 3458 (class 2606 OID 16640)
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (client_id);


--
-- TOC entry 3485 (class 2606 OID 16770)
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_id, product_id);


--
-- TOC entry 3469 (class 2606 OID 16701)
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- TOC entry 3466 (class 2606 OID 16665)
-- Name: payment_information payment_information_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.payment_information
    ADD CONSTRAINT payment_information_pkey PRIMARY KEY (payinfo_id);


--
-- TOC entry 3475 (class 2606 OID 16735)
-- Name: products products_article_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.products
    ADD CONSTRAINT products_article_key UNIQUE (article);


--
-- TOC entry 3477 (class 2606 OID 16733)
-- Name: products products_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- TOC entry 3479 (class 2606 OID 16765)
-- Name: staff staff_email_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.staff
    ADD CONSTRAINT staff_email_key UNIQUE (email);


--
-- TOC entry 3481 (class 2606 OID 16761)
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);


--
-- TOC entry 3483 (class 2606 OID 16763)
-- Name: staff staff_username_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.staff
    ADD CONSTRAINT staff_username_key UNIQUE (username);


--
-- TOC entry 3487 (class 2606 OID 16800)
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (audit_log_id);


--
-- TOC entry 3489 (class 2606 OID 25228)
-- Name: function_calls function_calls_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.function_calls
    ADD CONSTRAINT function_calls_pkey PRIMARY KEY (call_id);


--
-- TOC entry 3461 (class 2606 OID 16656)
-- Name: payment_method payment_method_method_name_key; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.payment_method
    ADD CONSTRAINT payment_method_method_name_key UNIQUE (method_name);


--
-- TOC entry 3463 (class 2606 OID 16654)
-- Name: payment_method payment_method_pkey; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.payment_method
    ADD CONSTRAINT payment_method_pkey PRIMARY KEY (method_id);


--
-- TOC entry 3471 (class 2606 OID 16723)
-- Name: product_category product_category_category_name_key; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.product_category
    ADD CONSTRAINT product_category_category_name_key UNIQUE (category_name);


--
-- TOC entry 3473 (class 2606 OID 16721)
-- Name: product_category product_category_pkey; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.product_category
    ADD CONSTRAINT product_category_pkey PRIMARY KEY (category_id);


--
-- TOC entry 3459 (class 1259 OID 16645)
-- Name: idx_clients_status; Type: INDEX; Schema: app; Owner: postgres
--

CREATE INDEX idx_clients_status ON app.clients USING btree (status);


--
-- TOC entry 3467 (class 1259 OID 16712)
-- Name: idx_orders_client; Type: INDEX; Schema: app; Owner: postgres
--

CREATE INDEX idx_orders_client ON app.orders USING btree (client_id);


--
-- TOC entry 3464 (class 1259 OID 16678)
-- Name: idx_payment_client; Type: INDEX; Schema: app; Owner: postgres
--

CREATE INDEX idx_payment_client ON app.payment_information USING btree (client_id);


--
-- TOC entry 3501 (class 2620 OID 25207)
-- Name: orders trg_check_total_amount; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_check_total_amount BEFORE INSERT OR UPDATE ON app.orders FOR EACH ROW EXECUTE FUNCTION app.check_total_amount_trigger();

ALTER TABLE app.orders DISABLE TRIGGER trg_check_total_amount;


--
-- TOC entry 3505 (class 2620 OID 25041)
-- Name: staff trg_log_admins_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_admins_changes AFTER INSERT OR DELETE OR UPDATE ON app.staff FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3498 (class 2620 OID 25040)
-- Name: clients trg_log_clients_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_clients_changes AFTER INSERT OR DELETE OR UPDATE ON app.clients FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3502 (class 2620 OID 25042)
-- Name: orders trg_log_orders_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_orders_changes AFTER INSERT OR DELETE OR UPDATE ON app.orders FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3500 (class 2620 OID 25039)
-- Name: payment_information trg_log_payment_information_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_payment_information_changes AFTER INSERT OR DELETE OR UPDATE ON app.payment_information FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3504 (class 2620 OID 25037)
-- Name: products trg_log_products_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_products_changes AFTER INSERT OR DELETE OR UPDATE ON app.products FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3499 (class 2620 OID 25043)
-- Name: payment_method trg_log_payment_method_changes; Type: TRIGGER; Schema: ref; Owner: postgres
--

CREATE TRIGGER trg_log_payment_method_changes AFTER INSERT OR DELETE OR UPDATE ON ref.payment_method FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3503 (class 2620 OID 25038)
-- Name: product_category trg_log_product_category_changes; Type: TRIGGER; Schema: ref; Owner: postgres
--

CREATE TRIGGER trg_log_product_category_changes AFTER INSERT OR DELETE OR UPDATE ON ref.product_category FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3495 (class 2606 OID 16771)
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES app.orders(order_id) ON DELETE CASCADE;


--
-- TOC entry 3496 (class 2606 OID 16776)
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.products(product_id) ON DELETE CASCADE;


--
-- TOC entry 3492 (class 2606 OID 16702)
-- Name: orders orders_client_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.orders
    ADD CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES app.clients(client_id) ON DELETE CASCADE;


--
-- TOC entry 3493 (class 2606 OID 16707)
-- Name: orders orders_payinfo_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.orders
    ADD CONSTRAINT orders_payinfo_id_fkey FOREIGN KEY (payinfo_id) REFERENCES app.payment_information(payinfo_id);


--
-- TOC entry 3490 (class 2606 OID 16668)
-- Name: payment_information payment_information_client_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.payment_information
    ADD CONSTRAINT payment_information_client_id_fkey FOREIGN KEY (client_id) REFERENCES app.clients(client_id) ON DELETE CASCADE;


--
-- TOC entry 3491 (class 2606 OID 16673)
-- Name: payment_information payment_information_method_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.payment_information
    ADD CONSTRAINT payment_information_method_id_fkey FOREIGN KEY (method_id) REFERENCES ref.payment_method(method_id);


--
-- TOC entry 3494 (class 2606 OID 16736)
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES ref.product_category(category_id);


--
-- TOC entry 3497 (class 2606 OID 16801)
-- Name: audit_log audit_log_staff_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.audit_log
    ADD CONSTRAINT audit_log_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES app.staff(staff_id);


--
-- TOC entry 3678 (class 0 OID 0)
-- Dependencies: 9
-- Name: SCHEMA app; Type: ACL; Schema: -; Owner: app_owner
--

GRANT USAGE ON SCHEMA app TO app_reader;
GRANT USAGE ON SCHEMA app TO app_writer;
GRANT ALL ON SCHEMA app TO ddl_admin;
GRANT USAGE ON SCHEMA app TO dml_admin;
GRANT USAGE ON SCHEMA app TO security_admin;


--
-- TOC entry 3679 (class 0 OID 0)
-- Dependencies: 13
-- Name: SCHEMA audit; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA audit TO auditor;
GRANT ALL ON SCHEMA audit TO ddl_admin;
GRANT USAGE ON SCHEMA audit TO security_admin;


--
-- TOC entry 3680 (class 0 OID 0)
-- Dependencies: 10
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO ddl_admin;


--
-- TOC entry 3681 (class 0 OID 0)
-- Dependencies: 11
-- Name: SCHEMA ref; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA ref TO app_reader;
GRANT USAGE ON SCHEMA ref TO app_writer;
GRANT USAGE ON SCHEMA ref TO app_owner;
GRANT ALL ON SCHEMA ref TO ddl_admin;
GRANT USAGE ON SCHEMA ref TO dml_admin;
GRANT USAGE ON SCHEMA ref TO security_admin;


--
-- TOC entry 3682 (class 0 OID 0)
-- Dependencies: 12
-- Name: SCHEMA stg; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA stg TO ddl_admin;
GRANT USAGE ON SCHEMA stg TO dml_admin;
GRANT USAGE ON SCHEMA stg TO security_admin;


--
-- TOC entry 3685 (class 0 OID 0)
-- Dependencies: 299
-- Name: FUNCTION cancel_order(p_order_id integer); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.cancel_order(p_order_id integer) TO app_owner;


--
-- TOC entry 3686 (class 0 OID 0)
-- Dependencies: 286
-- Name: FUNCTION check_total_amount_trigger(); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.check_total_amount_trigger() TO app_owner;


--
-- TOC entry 3687 (class 0 OID 0)
-- Dependencies: 300
-- Name: FUNCTION create_order(p_client_id integer, p_payinfo_id integer, p_delivery_address character varying, p_items json); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.create_order(p_client_id integer, p_payinfo_id integer, p_delivery_address character varying, p_items json) TO app_owner;


--
-- TOC entry 3689 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE clients; Type: ACL; Schema: app; Owner: postgres
--

GRANT SELECT ON TABLE app.clients TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.clients TO app_writer;
GRANT ALL ON TABLE app.clients TO app_owner;
GRANT SELECT ON TABLE app.clients TO auditor;
GRANT ALL ON TABLE app.clients TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.clients TO dml_admin;


--
-- TOC entry 3691 (class 0 OID 0)
-- Dependencies: 225
-- Name: SEQUENCE clients_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.clients_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.clients_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.clients_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.clients_id_seq TO dml_admin;


--
-- TOC entry 3693 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE order_items; Type: ACL; Schema: app; Owner: postgres
--

GRANT SELECT ON TABLE app.order_items TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.order_items TO app_writer;
GRANT ALL ON TABLE app.order_items TO app_owner;
GRANT SELECT ON TABLE app.order_items TO auditor;
GRANT ALL ON TABLE app.order_items TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.order_items TO dml_admin;


--
-- TOC entry 3694 (class 0 OID 0)
-- Dependencies: 244
-- Name: TABLE order_items_backup; Type: ACL; Schema: app; Owner: postgres
--

GRANT SELECT ON TABLE app.order_items_backup TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.order_items_backup TO app_writer;
GRANT ALL ON TABLE app.order_items_backup TO app_owner;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.order_items_backup TO dml_admin;


--
-- TOC entry 3696 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE orders; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON TABLE app.orders TO app_owner;
GRANT ALL ON TABLE app.orders TO ddl_admin;
GRANT SELECT ON TABLE app.orders TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.orders TO app_writer;
GRANT SELECT ON TABLE app.orders TO auditor;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.orders TO dml_admin;


--
-- TOC entry 3697 (class 0 OID 0)
-- Dependencies: 243
-- Name: TABLE orders_backup; Type: ACL; Schema: app; Owner: postgres
--

GRANT SELECT ON TABLE app.orders_backup TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.orders_backup TO app_writer;
GRANT ALL ON TABLE app.orders_backup TO app_owner;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.orders_backup TO dml_admin;


--
-- TOC entry 3699 (class 0 OID 0)
-- Dependencies: 231
-- Name: SEQUENCE orders_order_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.orders_order_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.orders_order_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.orders_order_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.orders_order_id_seq TO dml_admin;


--
-- TOC entry 3701 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE payment_information; Type: ACL; Schema: app; Owner: postgres
--

GRANT SELECT ON TABLE app.payment_information TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.payment_information TO app_writer;
GRANT ALL ON TABLE app.payment_information TO app_owner;
GRANT SELECT ON TABLE app.payment_information TO auditor;
GRANT ALL ON TABLE app.payment_information TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.payment_information TO dml_admin;


--
-- TOC entry 3703 (class 0 OID 0)
-- Dependencies: 229
-- Name: SEQUENCE payment_information_info_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO dml_admin;


--
-- TOC entry 3705 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE products; Type: ACL; Schema: app; Owner: postgres
--

GRANT SELECT ON TABLE app.products TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.products TO app_writer;
GRANT ALL ON TABLE app.products TO app_owner;
GRANT SELECT ON TABLE app.products TO auditor;
GRANT ALL ON TABLE app.products TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.products TO dml_admin;


--
-- TOC entry 3707 (class 0 OID 0)
-- Dependencies: 235
-- Name: SEQUENCE products_product_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.products_product_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.products_product_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.products_product_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.products_product_id_seq TO dml_admin;


--
-- TOC entry 3709 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE staff; Type: ACL; Schema: app; Owner: postgres
--

GRANT SELECT ON TABLE app.staff TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.staff TO app_writer;
GRANT ALL ON TABLE app.staff TO app_owner;
GRANT SELECT ON TABLE app.staff TO auditor;
GRANT ALL ON TABLE app.staff TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.staff TO dml_admin;


--
-- TOC entry 3711 (class 0 OID 0)
-- Dependencies: 237
-- Name: SEQUENCE staff_staff_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO dml_admin;


--
-- TOC entry 3713 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE audit_log; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT ON TABLE audit.audit_log TO auditor;


--
-- TOC entry 3715 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE function_calls; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT ON TABLE audit.function_calls TO auditor;


--
-- TOC entry 3717 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE login_log; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT ON TABLE audit.login_log TO auditor;


--
-- TOC entry 3718 (class 0 OID 0)
-- Dependencies: 22
-- Name: TABLE pg_auth_members; Type: ACL; Schema: pg_catalog; Owner: postgres
--

GRANT SELECT ON TABLE pg_catalog.pg_auth_members TO security_admin;


--
-- TOC entry 3719 (class 0 OID 0)
-- Dependencies: 43
-- Name: TABLE pg_namespace; Type: ACL; Schema: pg_catalog; Owner: postgres
--

GRANT SELECT ON TABLE pg_catalog.pg_namespace TO security_admin;


--
-- TOC entry 3720 (class 0 OID 0)
-- Dependencies: 78
-- Name: TABLE pg_roles; Type: ACL; Schema: pg_catalog; Owner: postgres
--

GRANT SELECT ON TABLE pg_catalog.pg_roles TO security_admin;


--
-- TOC entry 3721 (class 0 OID 0)
-- Dependencies: 85
-- Name: TABLE pg_tables; Type: ACL; Schema: pg_catalog; Owner: postgres
--

GRANT SELECT ON TABLE pg_catalog.pg_tables TO security_admin;


--
-- TOC entry 3723 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE payment_method; Type: ACL; Schema: ref; Owner: postgres
--

GRANT SELECT ON TABLE ref.payment_method TO app_reader;
GRANT SELECT ON TABLE ref.payment_method TO app_writer;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ref.payment_method TO dml_admin;


--
-- TOC entry 3725 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE payment_method_method_id_seq; Type: ACL; Schema: ref; Owner: postgres
--

GRANT ALL ON SEQUENCE ref.payment_method_method_id_seq TO dml_admin;


--
-- TOC entry 3727 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE product_category; Type: ACL; Schema: ref; Owner: postgres
--

GRANT SELECT ON TABLE ref.product_category TO app_reader;
GRANT SELECT ON TABLE ref.product_category TO app_writer;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ref.product_category TO dml_admin;


--
-- TOC entry 3729 (class 0 OID 0)
-- Dependencies: 233
-- Name: SEQUENCE product_category_category_id_seq; Type: ACL; Schema: ref; Owner: postgres
--

GRANT ALL ON SEQUENCE ref.product_category_category_id_seq TO dml_admin;


--
-- TOC entry 2177 (class 826 OID 16858)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT USAGE ON SEQUENCES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON SEQUENCES TO app_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT USAGE ON SEQUENCES TO dml_admin;


--
-- TOC entry 2170 (class 826 OID 16866)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA app GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2163 (class 826 OID 16859)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: app; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON FUNCTIONS TO app_owner;


--
-- TOC entry 2180 (class 826 OID 16857)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: app; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT ON TABLES TO app_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON TABLES TO app_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;


--
-- TOC entry 2165 (class 826 OID 16861)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: app; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA app GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2174 (class 826 OID 16870)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: audit; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA audit GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2164 (class 826 OID 16860)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: audit; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA audit GRANT SELECT ON TABLES TO auditor;


--
-- TOC entry 2169 (class 826 OID 16865)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: audit; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA audit GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2171 (class 826 OID 16867)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA public GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2166 (class 826 OID 16862)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA public GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2172 (class 826 OID 16868)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: ref; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA ref GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2176 (class 826 OID 16872)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: ref; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT USAGE ON SEQUENCES TO dml_admin;


--
-- TOC entry 2179 (class 826 OID 16856)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ref; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT ON TABLES TO app_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT ON TABLES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;


--
-- TOC entry 2167 (class 826 OID 16863)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ref; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA ref GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2173 (class 826 OID 16869)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: stg; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA stg GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2178 (class 826 OID 16873)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: stg; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA stg GRANT USAGE ON SEQUENCES TO dml_admin;


--
-- TOC entry 2168 (class 826 OID 16864)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: stg; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA stg GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2175 (class 826 OID 16871)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: stg; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA stg GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;


--
-- TOC entry 3429 (class 3466 OID 25142)
-- Name: login_audit_tg; Type: EVENT TRIGGER; Schema: -; Owner: postgres
--

CREATE EVENT TRIGGER login_audit_tg ON login
   EXECUTE FUNCTION audit.login_audit();


ALTER EVENT TRIGGER login_audit_tg OWNER TO postgres;

-- Completed on 2025-11-06 22:01:15 +07

--
-- PostgreSQL database dump complete
--

\unrestrict 2koUKPsqLPZ0oRtFd9DjtgvwgfgFhTYl6JbImJOjlKaVq2F14Y5cbedMokvtcVK


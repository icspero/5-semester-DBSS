--
-- PostgreSQL database dump
--

\restrict IX0eIM0RFqlLeTaOtuKOk0tWDLkd3cCurJiEe5XPN3umvdBv8NT0Q2f5pOvtdfy

-- Dumped from database version 17.6 (Ubuntu 17.6-1.pgdg24.04+1)
-- Dumped by pg_dump version 17.6 (Ubuntu 17.6-1.pgdg24.04+1)

-- Started on 2025-10-20 16:34:30 +07

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
-- TOC entry 3658 (class 0 OID 0)
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
-- TOC entry 3659 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 944 (class 1247 OID 16782)
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
-- TOC entry 911 (class 1247 OID 16622)
-- Name: clients_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.clients_status AS ENUM (
    'Активен',
    'Неактивен',
    'Заблокирован'
);


ALTER TYPE public.clients_status OWNER TO postgres;

--
-- TOC entry 923 (class 1247 OID 16680)
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
-- TOC entry 935 (class 1247 OID 16743)
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
-- TOC entry 281 (class 1255 OID 25035)
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

	BEGIN
		v_staff_id := current_setting('app.current_staff_id', true)::INT;
	EXCEPTION WHEN invalid_text_representation THEN
		v_staff_id := -1;
	END;
	
	IF v_staff_id IS NULL THEN
		v_staff_id := -1;
	END IF;
	
	IF TG_OP = 'INSERT' THEN
		v_action := 'CREATE';
	ELSIF TG_OP = 'UPDATE' THEN
		v_action := 'UPDATE';
	ELSIF TG_OP = 'DELETE' THEN
		v_action := 'DELETE';
	ELSE
		v_action := 'OTHER';
	END IF;
	
	INSERT INTO audit.audit_log (staff_id, action_time, action_type, action_description, success)
	VALUES (v_staff_id, now(), v_action, format('Таблица: %s, действие: %s', TG_TABLE_NAME, TG_OP), TRUE);
	
	RETURN NULL;
END;
$$;


ALTER FUNCTION audit.log_action() OWNER TO postgres;

--
-- TOC entry 282 (class 1255 OID 25141)
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
-- TOC entry 3660 (class 0 OID 0)
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
-- TOC entry 3662 (class 0 OID 0)
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
-- TOC entry 3664 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE order_items; Type: COMMENT; Schema: app; Owner: postgres
--

COMMENT ON TABLE app.order_items IS 'Таблица M:N, чтобы один заказ мог хранить много товаров';


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
-- TOC entry 3666 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE orders; Type: COMMENT; Schema: app; Owner: postgres
--

COMMENT ON TABLE app.orders IS 'Таблица с заказами';


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
-- TOC entry 3668 (class 0 OID 0)
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
-- TOC entry 3670 (class 0 OID 0)
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
-- TOC entry 3672 (class 0 OID 0)
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
-- TOC entry 3674 (class 0 OID 0)
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
-- TOC entry 3676 (class 0 OID 0)
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
    full_name character varying(50) NOT NULL,
    date_of_creation timestamp without time zone DEFAULT now(),
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE app.staff OWNER TO postgres;

--
-- TOC entry 3678 (class 0 OID 0)
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
-- TOC entry 3680 (class 0 OID 0)
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
-- TOC entry 3682 (class 0 OID 0)
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
-- TOC entry 3684 (class 0 OID 0)
-- Dependencies: 240
-- Name: audit_log_audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: postgres
--

ALTER SEQUENCE audit.audit_log_audit_log_id_seq OWNED BY audit.audit_log.audit_log_id;


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
-- TOC entry 3690 (class 0 OID 0)
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
-- TOC entry 3692 (class 0 OID 0)
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
-- TOC entry 3694 (class 0 OID 0)
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
-- TOC entry 3696 (class 0 OID 0)
-- Dependencies: 233
-- Name: product_category_category_id_seq; Type: SEQUENCE OWNED BY; Schema: ref; Owner: postgres
--

ALTER SEQUENCE ref.product_category_category_id_seq OWNED BY ref.product_category.category_id;


--
-- TOC entry 3414 (class 2604 OID 16633)
-- Name: clients client_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.clients ALTER COLUMN client_id SET DEFAULT nextval('app.clients_id_seq'::regclass);


--
-- TOC entry 3419 (class 2604 OID 16697)
-- Name: orders order_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.orders ALTER COLUMN order_id SET DEFAULT nextval('app.orders_order_id_seq'::regclass);


--
-- TOC entry 3418 (class 2604 OID 16661)
-- Name: payment_information payinfo_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.payment_information ALTER COLUMN payinfo_id SET DEFAULT nextval('app.payment_information_info_id_seq'::regclass);


--
-- TOC entry 3423 (class 2604 OID 16728)
-- Name: products product_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.products ALTER COLUMN product_id SET DEFAULT nextval('app.products_product_id_seq'::regclass);


--
-- TOC entry 3425 (class 2604 OID 16755)
-- Name: staff staff_id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.staff ALTER COLUMN staff_id SET DEFAULT nextval('app.staff_staff_id_seq'::regclass);


--
-- TOC entry 3428 (class 2604 OID 16795)
-- Name: audit_log audit_log_id; Type: DEFAULT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.audit_log ALTER COLUMN audit_log_id SET DEFAULT nextval('audit.audit_log_audit_log_id_seq'::regclass);


--
-- TOC entry 3417 (class 2604 OID 16650)
-- Name: payment_method method_id; Type: DEFAULT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.payment_method ALTER COLUMN method_id SET DEFAULT nextval('ref.payment_method_method_id_seq'::regclass);


--
-- TOC entry 3422 (class 2604 OID 16717)
-- Name: product_category category_id; Type: DEFAULT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.product_category ALTER COLUMN category_id SET DEFAULT nextval('ref.product_category_category_id_seq'::regclass);


--
-- TOC entry 3631 (class 0 OID 16630)
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
-- TOC entry 3644 (class 0 OID 16766)
-- Dependencies: 239
-- Data for Name: order_items; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.order_items (order_id, product_id) FROM stdin;
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
\.


--
-- TOC entry 3637 (class 0 OID 16694)
-- Dependencies: 232
-- Data for Name: orders; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.orders (order_id, client_id, payinfo_id, order_date, status, total_amount, delivery_address, date_of_creation) FROM stdin;
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
\.


--
-- TOC entry 3635 (class 0 OID 16658)
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
-- TOC entry 3641 (class 0 OID 16725)
-- Dependencies: 236
-- Data for Name: products; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.products (product_id, category_id, product_name, price, stock_quantity, article, is_active) FROM stdin;
1	1	iPhone 99	59999.00	15	ART-EL-0001	t
2	1	Air Pods 10	4999.00	50	ART-EL-0002	t
3	2	Книга: Алгоритмы	1299.00	30	ART-BK-0001	t
4	3	Футболка Стетхэм	799.00	100	ART-CL-0001	t
5	4	Светильник	1999.00	20	ART-HH-0001	t
6	5	Крем увлажняющий	599.00	40	ART-CM-0001	t
7	6	Гантели 5кг	2499.00	25	ART-SP-0001	t
8	1	iPad	29999.00	10	ART-EL-0003	t
9	2	Книга: SQL для профи	999.00	12	ART-BK-0002	t
10	3	Куртка зимняя	8999.00	8	ART-CL-0002	t
11	1	MacBook Pro	450000.00	7	ART-EL-0008	t
\.


--
-- TOC entry 3643 (class 0 OID 16752)
-- Dependencies: 238
-- Data for Name: staff; Type: TABLE DATA; Schema: app; Owner: postgres
--

COPY app.staff (staff_id, username, password_hash, email, role, full_name, date_of_creation, is_active) FROM stdin;
1	manager1	$2a$06$YFfHkZO3A8JGRh8yygiFaucT1AvFhn0jr/55PjXJLJ.vDJOUEyPbW	mgr1@example.com	Менеджер	Иван Иванов Иванович	2025-01-05 09:00:00	t
2	admin	$2a$06$vkfZ951mB5fcxCGiROjPze6f4WVBOef9pr/wmv/4zx/OUhPOvhHDq	admin@example.com	Администратор	Мария Морозова Анатольевна	2025-01-06 09:30:00	t
3	manager2	$2a$06$mWCdT7b.8N9Os6KPbj1kvuCKwOAmoB5zkAGOgarYb3ZAACWELthUO	mgr21@example.com	Бухгалтер	Алексей Баранов Климович	2025-02-02 10:00:00	t
4	stock1	$2a$06$v9ZSrHpjG6bKe.0zUdMvc.VaxAogZiFkr5EVhkp6BTqJOu/YXdUbG	stock1@example.com	Складской	Пётр Александров Евгеньевич	2025-02-10 11:15:00	t
5	manager3	$2a$06$hH8daHZLo2oIW83.HYw/Gu/BnurUHBZ5W83BfVLdEI7iGTwhrOXfG	mgr3@example.com	Менеджер	Ольга Плотникова Сергеевна	2025-03-12 12:00:00	t
6	staff6	$2a$06$0Qn7Akw0blfo/TEi08u.LujWoAuP4SsnVR0vHkE86UZG2lmF0XhZy	staff6@example.com	Складской	Сергей Слемзин Владимирович	2025-03-20 13:10:00	t
7	staff7	$2a$06$05kxYRCWqudIEfFyjDjj7.1Do7UfTLJYTDZsJad2wTMUno6/XOtqa	staff7@example.com	Бухгалтер	Елена Брит Алексеевна	2025-04-01 14:20:00	t
8	staff8	$2a$06$tF3XGHOOASwtUYil4M95Wu5EQi8q.QwdEpjz2YiZ/xnTHKubUQGzG	staff8@example.com	Менеджер	Дмитрий Мартынов Егорович	2025-04-15 15:30:00	t
9	staff9	$2a$06$fYuhsSUXA9HXmOp4ObRLyOIYoB6Cq2r3C/5fg7QnLXj9EHHUeLeSi	staff9@example.com	Администратор	Наталья Федорова Афанасьевна	2025-05-01 16:40:00	t
10	staff10	$2a$06$EytOfTmjg9OksYf0flFIV.PYCn1l3hTtUHHbllACXXPEKUADaDtUG	staff10@example.com	Складской	Игорь Самойлов Сергеевич	2025-05-10 17:50:00	t
\.


--
-- TOC entry 3646 (class 0 OID 16792)
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
\.


--
-- TOC entry 3647 (class 0 OID 25134)
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
\.


--
-- TOC entry 3633 (class 0 OID 16647)
-- Dependencies: 228
-- Data for Name: payment_method; Type: TABLE DATA; Schema: ref; Owner: postgres
--

COPY ref.payment_method (method_id, method_name, description) FROM stdin;
1	Карта	Оплата картой
2	Наличные	Оплата наличными
\.


--
-- TOC entry 3639 (class 0 OID 16714)
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
-- TOC entry 3698 (class 0 OID 0)
-- Dependencies: 225
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.clients_id_seq', 1, false);


--
-- TOC entry 3699 (class 0 OID 0)
-- Dependencies: 231
-- Name: orders_order_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.orders_order_id_seq', 1, false);


--
-- TOC entry 3700 (class 0 OID 0)
-- Dependencies: 229
-- Name: payment_information_info_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.payment_information_info_id_seq', 1, false);


--
-- TOC entry 3701 (class 0 OID 0)
-- Dependencies: 235
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.products_product_id_seq', 22, true);


--
-- TOC entry 3702 (class 0 OID 0)
-- Dependencies: 237
-- Name: staff_staff_id_seq; Type: SEQUENCE SET; Schema: app; Owner: postgres
--

SELECT pg_catalog.setval('app.staff_staff_id_seq', 1, false);


--
-- TOC entry 3703 (class 0 OID 0)
-- Dependencies: 240
-- Name: audit_log_audit_log_id_seq; Type: SEQUENCE SET; Schema: audit; Owner: postgres
--

SELECT pg_catalog.setval('audit.audit_log_audit_log_id_seq', 20, true);


--
-- TOC entry 3704 (class 0 OID 0)
-- Dependencies: 227
-- Name: payment_method_method_id_seq; Type: SEQUENCE SET; Schema: ref; Owner: postgres
--

SELECT pg_catalog.setval('ref.payment_method_method_id_seq', 1, false);


--
-- TOC entry 3705 (class 0 OID 0)
-- Dependencies: 233
-- Name: product_category_category_id_seq; Type: SEQUENCE SET; Schema: ref; Owner: postgres
--

SELECT pg_catalog.setval('ref.product_category_category_id_seq', 1, false);


--
-- TOC entry 3436 (class 2606 OID 16642)
-- Name: clients clients_email_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.clients
    ADD CONSTRAINT clients_email_key UNIQUE (email);


--
-- TOC entry 3438 (class 2606 OID 16644)
-- Name: clients clients_phone_number_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.clients
    ADD CONSTRAINT clients_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 3440 (class 2606 OID 16640)
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (client_id);


--
-- TOC entry 3467 (class 2606 OID 16770)
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_id, product_id);


--
-- TOC entry 3451 (class 2606 OID 16701)
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- TOC entry 3448 (class 2606 OID 16665)
-- Name: payment_information payment_information_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.payment_information
    ADD CONSTRAINT payment_information_pkey PRIMARY KEY (payinfo_id);


--
-- TOC entry 3457 (class 2606 OID 16735)
-- Name: products products_article_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.products
    ADD CONSTRAINT products_article_key UNIQUE (article);


--
-- TOC entry 3459 (class 2606 OID 16733)
-- Name: products products_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- TOC entry 3461 (class 2606 OID 16765)
-- Name: staff staff_email_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.staff
    ADD CONSTRAINT staff_email_key UNIQUE (email);


--
-- TOC entry 3463 (class 2606 OID 16761)
-- Name: staff staff_pkey; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (staff_id);


--
-- TOC entry 3465 (class 2606 OID 16763)
-- Name: staff staff_username_key; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.staff
    ADD CONSTRAINT staff_username_key UNIQUE (username);


--
-- TOC entry 3469 (class 2606 OID 16800)
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (audit_log_id);


--
-- TOC entry 3443 (class 2606 OID 16656)
-- Name: payment_method payment_method_method_name_key; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.payment_method
    ADD CONSTRAINT payment_method_method_name_key UNIQUE (method_name);


--
-- TOC entry 3445 (class 2606 OID 16654)
-- Name: payment_method payment_method_pkey; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.payment_method
    ADD CONSTRAINT payment_method_pkey PRIMARY KEY (method_id);


--
-- TOC entry 3453 (class 2606 OID 16723)
-- Name: product_category product_category_category_name_key; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.product_category
    ADD CONSTRAINT product_category_category_name_key UNIQUE (category_name);


--
-- TOC entry 3455 (class 2606 OID 16721)
-- Name: product_category product_category_pkey; Type: CONSTRAINT; Schema: ref; Owner: postgres
--

ALTER TABLE ONLY ref.product_category
    ADD CONSTRAINT product_category_pkey PRIMARY KEY (category_id);


--
-- TOC entry 3441 (class 1259 OID 16645)
-- Name: idx_clients_status; Type: INDEX; Schema: app; Owner: postgres
--

CREATE INDEX idx_clients_status ON app.clients USING btree (status);


--
-- TOC entry 3449 (class 1259 OID 16712)
-- Name: idx_orders_client; Type: INDEX; Schema: app; Owner: postgres
--

CREATE INDEX idx_orders_client ON app.orders USING btree (client_id);


--
-- TOC entry 3446 (class 1259 OID 16678)
-- Name: idx_payment_client; Type: INDEX; Schema: app; Owner: postgres
--

CREATE INDEX idx_payment_client ON app.payment_information USING btree (client_id);


--
-- TOC entry 3484 (class 2620 OID 25041)
-- Name: staff trg_log_admins_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_admins_changes AFTER INSERT OR DELETE OR UPDATE ON app.staff FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3478 (class 2620 OID 25040)
-- Name: clients trg_log_clients_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_clients_changes AFTER INSERT OR DELETE OR UPDATE ON app.clients FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3481 (class 2620 OID 25042)
-- Name: orders trg_log_orders_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_orders_changes AFTER INSERT OR DELETE OR UPDATE ON app.orders FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3480 (class 2620 OID 25039)
-- Name: payment_information trg_log_payment_information_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_payment_information_changes AFTER INSERT OR DELETE OR UPDATE ON app.payment_information FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3483 (class 2620 OID 25037)
-- Name: products trg_log_products_changes; Type: TRIGGER; Schema: app; Owner: postgres
--

CREATE TRIGGER trg_log_products_changes AFTER INSERT OR DELETE OR UPDATE ON app.products FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3479 (class 2620 OID 25043)
-- Name: payment_method trg_log_payment_method_changes; Type: TRIGGER; Schema: ref; Owner: postgres
--

CREATE TRIGGER trg_log_payment_method_changes AFTER INSERT OR DELETE OR UPDATE ON ref.payment_method FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3482 (class 2620 OID 25038)
-- Name: product_category trg_log_product_category_changes; Type: TRIGGER; Schema: ref; Owner: postgres
--

CREATE TRIGGER trg_log_product_category_changes AFTER INSERT OR DELETE OR UPDATE ON ref.product_category FOR EACH STATEMENT EXECUTE FUNCTION audit.log_action();


--
-- TOC entry 3475 (class 2606 OID 16771)
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES app.orders(order_id) ON DELETE CASCADE;


--
-- TOC entry 3476 (class 2606 OID 16776)
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES app.products(product_id) ON DELETE CASCADE;


--
-- TOC entry 3472 (class 2606 OID 16702)
-- Name: orders orders_client_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.orders
    ADD CONSTRAINT orders_client_id_fkey FOREIGN KEY (client_id) REFERENCES app.clients(client_id) ON DELETE CASCADE;


--
-- TOC entry 3473 (class 2606 OID 16707)
-- Name: orders orders_payinfo_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.orders
    ADD CONSTRAINT orders_payinfo_id_fkey FOREIGN KEY (payinfo_id) REFERENCES app.payment_information(payinfo_id);


--
-- TOC entry 3470 (class 2606 OID 16668)
-- Name: payment_information payment_information_client_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.payment_information
    ADD CONSTRAINT payment_information_client_id_fkey FOREIGN KEY (client_id) REFERENCES app.clients(client_id) ON DELETE CASCADE;


--
-- TOC entry 3471 (class 2606 OID 16673)
-- Name: payment_information payment_information_method_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.payment_information
    ADD CONSTRAINT payment_information_method_id_fkey FOREIGN KEY (method_id) REFERENCES ref.payment_method(method_id);


--
-- TOC entry 3474 (class 2606 OID 16736)
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES ref.product_category(category_id);


--
-- TOC entry 3477 (class 2606 OID 16801)
-- Name: audit_log audit_log_staff_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.audit_log
    ADD CONSTRAINT audit_log_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES app.staff(staff_id);


--
-- TOC entry 3653 (class 0 OID 0)
-- Dependencies: 9
-- Name: SCHEMA app; Type: ACL; Schema: -; Owner: app_owner
--

GRANT USAGE ON SCHEMA app TO app_reader;
GRANT USAGE ON SCHEMA app TO app_writer;
GRANT ALL ON SCHEMA app TO ddl_admin;
GRANT USAGE ON SCHEMA app TO dml_admin;
GRANT USAGE ON SCHEMA app TO security_admin;


--
-- TOC entry 3654 (class 0 OID 0)
-- Dependencies: 13
-- Name: SCHEMA audit; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA audit TO auditor;
GRANT ALL ON SCHEMA audit TO ddl_admin;
GRANT USAGE ON SCHEMA audit TO security_admin;


--
-- TOC entry 3655 (class 0 OID 0)
-- Dependencies: 10
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO ddl_admin;


--
-- TOC entry 3656 (class 0 OID 0)
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
-- TOC entry 3657 (class 0 OID 0)
-- Dependencies: 12
-- Name: SCHEMA stg; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA stg TO ddl_admin;
GRANT USAGE ON SCHEMA stg TO dml_admin;
GRANT USAGE ON SCHEMA stg TO security_admin;


--
-- TOC entry 3661 (class 0 OID 0)
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
-- TOC entry 3663 (class 0 OID 0)
-- Dependencies: 225
-- Name: SEQUENCE clients_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.clients_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.clients_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.clients_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.clients_id_seq TO dml_admin;


--
-- TOC entry 3665 (class 0 OID 0)
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
-- TOC entry 3667 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE orders; Type: ACL; Schema: app; Owner: postgres
--

GRANT SELECT ON TABLE app.orders TO app_reader;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.orders TO app_writer;
GRANT ALL ON TABLE app.orders TO app_owner;
GRANT SELECT ON TABLE app.orders TO auditor;
GRANT ALL ON TABLE app.orders TO ddl_admin;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE app.orders TO dml_admin;


--
-- TOC entry 3669 (class 0 OID 0)
-- Dependencies: 231
-- Name: SEQUENCE orders_order_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.orders_order_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.orders_order_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.orders_order_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.orders_order_id_seq TO dml_admin;


--
-- TOC entry 3671 (class 0 OID 0)
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
-- TOC entry 3673 (class 0 OID 0)
-- Dependencies: 229
-- Name: SEQUENCE payment_information_info_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.payment_information_info_id_seq TO dml_admin;


--
-- TOC entry 3675 (class 0 OID 0)
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
-- TOC entry 3677 (class 0 OID 0)
-- Dependencies: 235
-- Name: SEQUENCE products_product_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.products_product_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.products_product_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.products_product_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.products_product_id_seq TO dml_admin;


--
-- TOC entry 3679 (class 0 OID 0)
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
-- TOC entry 3681 (class 0 OID 0)
-- Dependencies: 237
-- Name: SEQUENCE staff_staff_id_seq; Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO app_writer;
GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO app_owner;
GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO ddl_admin;
GRANT ALL ON SEQUENCE app.staff_staff_id_seq TO dml_admin;


--
-- TOC entry 3683 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE audit_log; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT ON TABLE audit.audit_log TO auditor;


--
-- TOC entry 3685 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE login_log; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT ON TABLE audit.login_log TO auditor;


--
-- TOC entry 3686 (class 0 OID 0)
-- Dependencies: 22
-- Name: TABLE pg_auth_members; Type: ACL; Schema: pg_catalog; Owner: postgres
--

GRANT SELECT ON TABLE pg_catalog.pg_auth_members TO security_admin;


--
-- TOC entry 3687 (class 0 OID 0)
-- Dependencies: 43
-- Name: TABLE pg_namespace; Type: ACL; Schema: pg_catalog; Owner: postgres
--

GRANT SELECT ON TABLE pg_catalog.pg_namespace TO security_admin;


--
-- TOC entry 3688 (class 0 OID 0)
-- Dependencies: 78
-- Name: TABLE pg_roles; Type: ACL; Schema: pg_catalog; Owner: postgres
--

GRANT SELECT ON TABLE pg_catalog.pg_roles TO security_admin;


--
-- TOC entry 3689 (class 0 OID 0)
-- Dependencies: 85
-- Name: TABLE pg_tables; Type: ACL; Schema: pg_catalog; Owner: postgres
--

GRANT SELECT ON TABLE pg_catalog.pg_tables TO security_admin;


--
-- TOC entry 3691 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE payment_method; Type: ACL; Schema: ref; Owner: postgres
--

GRANT SELECT ON TABLE ref.payment_method TO app_reader;
GRANT SELECT ON TABLE ref.payment_method TO app_writer;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ref.payment_method TO dml_admin;


--
-- TOC entry 3693 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE payment_method_method_id_seq; Type: ACL; Schema: ref; Owner: postgres
--

GRANT ALL ON SEQUENCE ref.payment_method_method_id_seq TO dml_admin;


--
-- TOC entry 3695 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE product_category; Type: ACL; Schema: ref; Owner: postgres
--

GRANT SELECT ON TABLE ref.product_category TO app_reader;
GRANT SELECT ON TABLE ref.product_category TO app_writer;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE ref.product_category TO dml_admin;


--
-- TOC entry 3697 (class 0 OID 0)
-- Dependencies: 233
-- Name: SEQUENCE product_category_category_id_seq; Type: ACL; Schema: ref; Owner: postgres
--

GRANT ALL ON SEQUENCE ref.product_category_category_id_seq TO dml_admin;


--
-- TOC entry 2161 (class 826 OID 16858)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT USAGE ON SEQUENCES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON SEQUENCES TO app_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT USAGE ON SEQUENCES TO dml_admin;


--
-- TOC entry 2154 (class 826 OID 16866)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: app; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA app GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2147 (class 826 OID 16859)
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: app; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON FUNCTIONS TO app_owner;


--
-- TOC entry 2164 (class 826 OID 16857)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: app; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT ON TABLES TO app_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT ALL ON TABLES TO app_owner;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA app GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;


--
-- TOC entry 2149 (class 826 OID 16861)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: app; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA app GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2158 (class 826 OID 16870)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: audit; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA audit GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2148 (class 826 OID 16860)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: audit; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA audit GRANT SELECT ON TABLES TO auditor;


--
-- TOC entry 2153 (class 826 OID 16865)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: audit; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA audit GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2155 (class 826 OID 16867)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA public GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2150 (class 826 OID 16862)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA public GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2156 (class 826 OID 16868)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: ref; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA ref GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2160 (class 826 OID 16872)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: ref; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT USAGE ON SEQUENCES TO dml_admin;


--
-- TOC entry 2163 (class 826 OID 16856)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ref; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT ON TABLES TO app_reader;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT ON TABLES TO app_writer;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA ref GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;


--
-- TOC entry 2151 (class 826 OID 16863)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: ref; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA ref GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2157 (class 826 OID 16869)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: stg; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA stg GRANT USAGE ON SEQUENCES TO ddl_admin;


--
-- TOC entry 2162 (class 826 OID 16873)
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: stg; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA stg GRANT USAGE ON SEQUENCES TO dml_admin;


--
-- TOC entry 2152 (class 826 OID 16864)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: stg; Owner: ddl_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE ddl_admin IN SCHEMA stg GRANT REFERENCES,TRIGGER ON TABLES TO ddl_admin;


--
-- TOC entry 2159 (class 826 OID 16871)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: stg; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA stg GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO dml_admin;


--
-- TOC entry 3413 (class 3466 OID 25142)
-- Name: login_audit_tg; Type: EVENT TRIGGER; Schema: -; Owner: postgres
--

CREATE EVENT TRIGGER login_audit_tg ON login
   EXECUTE FUNCTION audit.login_audit();


ALTER EVENT TRIGGER login_audit_tg OWNER TO postgres;

-- Completed on 2025-10-20 16:34:30 +07

--
-- PostgreSQL database dump complete
--

\unrestrict IX0eIM0RFqlLeTaOtuKOk0tWDLkd3cCurJiEe5XPN3umvdBv8NT0Q2f5pOvtdfy


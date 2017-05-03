--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.2
-- Dumped by pg_dump version 9.6.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE ads (
    id integer NOT NULL,
    title character varying,
    body text,
    image character varying,
    target_url text,
    organization_id integer,
    live boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: ads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE ads_id_seq OWNED BY ads.id;


--
-- Name: b_params; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE b_params (
    id integer NOT NULL,
    old_params text,
    bike_title character varying,
    creator_id integer,
    created_bike_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    bike_errors text,
    image character varying,
    image_tmp character varying,
    image_processed boolean DEFAULT true,
    id_token text,
    params json DEFAULT '{"bike":{}}'::json,
    origin character varying
);


--
-- Name: b_params_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE b_params_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: b_params_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE b_params_id_seq OWNED BY b_params.id;


--
-- Name: bike_organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE bike_organizations (
    id integer NOT NULL,
    bike_id integer,
    organization_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: bike_organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bike_organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bike_organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bike_organizations_id_seq OWNED BY bike_organizations.id;


--
-- Name: bikes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE bikes (
    id integer NOT NULL,
    name character varying,
    cycle_type_id integer,
    serial_number character varying NOT NULL,
    frame_model character varying,
    manufacturer_id integer,
    rear_tire_narrow boolean DEFAULT true,
    frame_material_id integer,
    number_of_seats integer,
    propulsion_type_id integer,
    creation_organization_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    stolen boolean DEFAULT false NOT NULL,
    propulsion_type_other character varying,
    manufacturer_other character varying,
    zipcode character varying,
    cached_data text,
    description text,
    owner_email text,
    thumb_path text,
    video_embed text,
    year integer,
    has_no_serial boolean DEFAULT false NOT NULL,
    creator_id integer,
    front_tire_narrow boolean,
    primary_frame_color_id integer,
    secondary_frame_color_id integer,
    tertiary_frame_color_id integer,
    handlebar_type_id integer,
    handlebar_type_other character varying,
    front_wheel_size_id integer,
    rear_wheel_size_id integer,
    rear_gear_type_id integer,
    front_gear_type_id integer,
    additional_registration character varying,
    belt_drive boolean DEFAULT false NOT NULL,
    coaster_brake boolean DEFAULT false NOT NULL,
    frame_size character varying,
    frame_size_unit character varying,
    serial_normalized character varying,
    pdf character varying,
    card_id integer,
    recovered boolean DEFAULT false NOT NULL,
    paint_id integer,
    registered_new boolean,
    example boolean DEFAULT false NOT NULL,
    country_id integer,
    stock_photo_url character varying,
    current_stolen_record_id integer,
    listing_order integer,
    approved_stolen boolean,
    all_description text,
    mnfg_name character varying,
    hidden boolean DEFAULT false NOT NULL,
    frame_size_number double precision,
    updator_id integer,
    is_for_sale boolean DEFAULT false NOT NULL,
    made_without_serial boolean DEFAULT false NOT NULL,
    stolen_lat double precision,
    stolen_long double precision,
    creation_state_id integer
);


--
-- Name: bikes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bikes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bikes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bikes_id_seq OWNED BY bikes.id;


--
-- Name: blogs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE blogs (
    id integer NOT NULL,
    title text,
    title_slug character varying,
    body text,
    body_abbr text,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    published_at timestamp without time zone,
    tags character varying,
    published boolean,
    old_title_slug character varying,
    description_abbr text,
    is_listicle boolean DEFAULT false NOT NULL,
    index_image character varying,
    index_image_id integer,
    index_image_lg character varying
);


--
-- Name: blogs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE blogs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blogs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE blogs_id_seq OWNED BY blogs.id;


--
-- Name: cgroups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE cgroups (
    id integer NOT NULL,
    name character varying,
    slug character varying,
    description character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: cgroups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cgroups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cgroups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cgroups_id_seq OWNED BY cgroups.id;


--
-- Name: colors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE colors (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    priority integer,
    display character varying
);


--
-- Name: colors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE colors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: colors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE colors_id_seq OWNED BY colors.id;


--
-- Name: components; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE components (
    id integer NOT NULL,
    cmodel_name character varying,
    year integer,
    description text,
    manufacturer_id integer,
    ctype_id integer,
    ctype_other character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    bike_id integer,
    front boolean,
    rear boolean,
    manufacturer_other character varying,
    serial_number character varying,
    is_stock boolean DEFAULT false NOT NULL
);


--
-- Name: components_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE components_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: components_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE components_id_seq OWNED BY components.id;


--
-- Name: countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE countries (
    id integer NOT NULL,
    name character varying,
    iso character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: countries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE countries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: countries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE countries_id_seq OWNED BY countries.id;


--
-- Name: creation_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE creation_states (
    id integer NOT NULL,
    bike_id integer,
    organization_id integer,
    origin character varying,
    is_bulk boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_pos boolean DEFAULT false NOT NULL,
    is_new boolean DEFAULT false NOT NULL,
    creator_id integer
);


--
-- Name: creation_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE creation_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: creation_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE creation_states_id_seq OWNED BY creation_states.id;


--
-- Name: ctypes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE ctypes (
    id integer NOT NULL,
    name character varying,
    slug character varying,
    secondary_name character varying,
    image character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    has_multiple boolean DEFAULT false NOT NULL,
    cgroup_id integer
);


--
-- Name: ctypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ctypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ctypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE ctypes_id_seq OWNED BY ctypes.id;


--
-- Name: customer_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE customer_contacts (
    id integer NOT NULL,
    user_id integer,
    user_email character varying,
    creator_id integer,
    creator_email character varying,
    title character varying,
    contact_type character varying,
    body text,
    bike_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    info_hash text
);


--
-- Name: customer_contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE customer_contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customer_contacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE customer_contacts_id_seq OWNED BY customer_contacts.id;


--
-- Name: cycle_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE cycle_types (
    id integer NOT NULL,
    name character varying,
    slug character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: cycle_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE cycle_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cycle_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE cycle_types_id_seq OWNED BY cycle_types.id;


--
-- Name: duplicate_bike_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE duplicate_bike_groups (
    id integer NOT NULL,
    ignore boolean DEFAULT false NOT NULL,
    added_bike_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: duplicate_bike_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE duplicate_bike_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: duplicate_bike_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE duplicate_bike_groups_id_seq OWNED BY duplicate_bike_groups.id;


--
-- Name: feedbacks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE feedbacks (
    id integer NOT NULL,
    name character varying,
    email character varying,
    title character varying,
    body text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    feedback_type character varying,
    feedback_hash text
);


--
-- Name: feedbacks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE feedbacks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: feedbacks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE feedbacks_id_seq OWNED BY feedbacks.id;


--
-- Name: flavor_texts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE flavor_texts (
    id integer NOT NULL,
    message character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: flavor_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE flavor_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flavor_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE flavor_texts_id_seq OWNED BY flavor_texts.id;


--
-- Name: frame_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE frame_materials (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    slug character varying
);


--
-- Name: frame_materials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE frame_materials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: frame_materials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE frame_materials_id_seq OWNED BY frame_materials.id;


--
-- Name: front_gear_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE front_gear_types (
    id integer NOT NULL,
    name character varying,
    count integer,
    internal boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    standard boolean,
    slug character varying
);


--
-- Name: front_gear_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE front_gear_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: front_gear_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE front_gear_types_id_seq OWNED BY front_gear_types.id;


--
-- Name: handlebar_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE handlebar_types (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    slug character varying
);


--
-- Name: handlebar_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE handlebar_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: handlebar_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE handlebar_types_id_seq OWNED BY handlebar_types.id;


--
-- Name: integrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE integrations (
    id integer NOT NULL,
    user_id integer,
    access_token text,
    provider_name character varying,
    information text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: integrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE integrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: integrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE integrations_id_seq OWNED BY integrations.id;


--
-- Name: listicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE listicles (
    id integer NOT NULL,
    list_order integer,
    body text,
    blog_id integer,
    image character varying,
    title text,
    body_html text,
    image_width integer,
    image_height integer,
    image_credits text,
    image_credits_html text,
    crop_top_offset integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: listicles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE listicles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listicles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE listicles_id_seq OWNED BY listicles.id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE locations (
    id integer NOT NULL,
    organization_id integer,
    zipcode character varying,
    city character varying,
    street character varying,
    phone character varying,
    email character varying,
    name character varying,
    latitude double precision,
    longitude double precision,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    shown boolean DEFAULT false,
    country_id integer,
    state_id integer
);


--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE locations_id_seq OWNED BY locations.id;


--
-- Name: lock_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE lock_types (
    id integer NOT NULL,
    name character varying,
    slug character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: lock_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE lock_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lock_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE lock_types_id_seq OWNED BY lock_types.id;


--
-- Name: locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE locks (
    id integer NOT NULL,
    lock_type_id integer DEFAULT 1,
    has_key boolean DEFAULT true,
    has_combination boolean,
    combination character varying,
    key_serial character varying,
    manufacturer_id integer,
    manufacturer_other character varying,
    user_id integer,
    lock_model character varying,
    notes text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: locks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE locks_id_seq OWNED BY locks.id;


--
-- Name: mail_snippets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE mail_snippets (
    id integer NOT NULL,
    name character varying,
    is_enabled boolean DEFAULT false NOT NULL,
    is_location_triggered boolean DEFAULT false NOT NULL,
    body text,
    address character varying,
    latitude double precision,
    longitude double precision,
    proximity_radius integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    organization_id integer
);


--
-- Name: mail_snippets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE mail_snippets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mail_snippets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE mail_snippets_id_seq OWNED BY mail_snippets.id;


--
-- Name: manufacturers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE manufacturers (
    id integer NOT NULL,
    name character varying,
    slug character varying,
    website character varying,
    frame_maker boolean,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    total_years_active character varying,
    notes text,
    open_year integer,
    close_year integer,
    logo character varying,
    description text,
    logo_source character varying
);


--
-- Name: manufacturers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE manufacturers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manufacturers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE manufacturers_id_seq OWNED BY manufacturers.id;


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE memberships (
    id integer NOT NULL,
    organization_id integer NOT NULL,
    user_id integer,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    invited_email character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- Name: memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE memberships_id_seq OWNED BY memberships.id;


--
-- Name: normalized_serial_segments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE normalized_serial_segments (
    id integer NOT NULL,
    segment character varying,
    bike_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    duplicate_bike_group_id integer
);


--
-- Name: normalized_serial_segments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE normalized_serial_segments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: normalized_serial_segments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE normalized_serial_segments_id_seq OWNED BY normalized_serial_segments.id;


--
-- Name: oauth_access_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE oauth_access_grants (
    id integer NOT NULL,
    resource_owner_id integer NOT NULL,
    application_id integer NOT NULL,
    token character varying NOT NULL,
    expires_in integer NOT NULL,
    redirect_uri text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    revoked_at timestamp without time zone,
    scopes character varying
);


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE oauth_access_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE oauth_access_grants_id_seq OWNED BY oauth_access_grants.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE oauth_access_tokens (
    id integer NOT NULL,
    resource_owner_id integer,
    application_id integer,
    token character varying NOT NULL,
    refresh_token character varying,
    expires_in integer,
    revoked_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    scopes character varying
);


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE oauth_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE oauth_access_tokens_id_seq OWNED BY oauth_access_tokens.id;


--
-- Name: oauth_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE oauth_applications (
    id integer NOT NULL,
    name character varying NOT NULL,
    uid character varying NOT NULL,
    secret character varying NOT NULL,
    redirect_uri text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    owner_id integer,
    owner_type character varying,
    is_internal boolean DEFAULT false NOT NULL,
    can_send_stolen_notifications boolean DEFAULT false NOT NULL,
    scopes character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE oauth_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE oauth_applications_id_seq OWNED BY oauth_applications.id;


--
-- Name: organization_deals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE organization_deals (
    id integer NOT NULL,
    organization_id integer,
    deal_name character varying,
    email character varying,
    user_id character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: organization_deals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE organization_deals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organization_deals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE organization_deals_id_seq OWNED BY organization_deals.id;


--
-- Name: organization_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE organization_invitations (
    id integer NOT NULL,
    invitee_email character varying,
    invitee_name character varying,
    invitee_id integer,
    organization_id integer,
    inviter_id integer,
    redeemed boolean,
    membership_role character varying DEFAULT 'member'::character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


--
-- Name: organization_invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE organization_invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organization_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE organization_invitations_id_seq OWNED BY organization_invitations.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE organizations (
    id integer NOT NULL,
    name character varying,
    slug character varying NOT NULL,
    available_invitation_count integer DEFAULT 10,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    website character varying,
    short_name character varying,
    show_on_map boolean,
    sent_invitation_count integer DEFAULT 0,
    deleted_at timestamp without time zone,
    is_suspended boolean DEFAULT false NOT NULL,
    auto_user_id integer,
    org_type character varying DEFAULT 'shop'::character varying NOT NULL,
    access_token character varying,
    new_bike_notification text,
    api_access_approved boolean DEFAULT false NOT NULL,
    approved boolean DEFAULT true,
    use_additional_registration_field boolean DEFAULT false NOT NULL,
    avatar character varying,
    is_paid boolean DEFAULT false NOT NULL,
    lock_show_on_map boolean DEFAULT false NOT NULL,
    landing_html text
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE organizations_id_seq OWNED BY organizations.id;


--
-- Name: other_listings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE other_listings (
    id integer NOT NULL,
    bike_id integer,
    url character varying,
    listing_type character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: other_listings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE other_listings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: other_listings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE other_listings_id_seq OWNED BY other_listings.id;


--
-- Name: ownerships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE ownerships (
    id integer NOT NULL,
    bike_id integer,
    user_id integer,
    owner_email character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_id integer,
    current boolean DEFAULT false,
    claimed boolean,
    example boolean DEFAULT false NOT NULL,
    send_email boolean DEFAULT true,
    user_hidden boolean DEFAULT false NOT NULL
);


--
-- Name: ownerships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ownerships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ownerships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE ownerships_id_seq OWNED BY ownerships.id;


--
-- Name: paints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE paints (
    id integer NOT NULL,
    name character varying,
    color_id integer,
    manufacturer_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    secondary_color_id integer,
    tertiary_color_id integer,
    bikes_count integer DEFAULT 0 NOT NULL
);


--
-- Name: paints_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE paints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: paints_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE paints_id_seq OWNED BY paints.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE payments (
    id integer NOT NULL,
    user_id integer,
    is_current boolean DEFAULT true,
    is_recurring boolean DEFAULT false NOT NULL,
    stripe_id character varying,
    last_payment_date timestamp without time zone,
    first_payment_date timestamp without time zone,
    amount integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    email character varying,
    is_payment boolean DEFAULT false NOT NULL
);


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE payments_id_seq OWNED BY payments.id;


--
-- Name: propulsion_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE propulsion_types (
    id integer NOT NULL,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    slug character varying
);


--
-- Name: propulsion_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE propulsion_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: propulsion_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE propulsion_types_id_seq OWNED BY propulsion_types.id;


--
-- Name: public_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public_images (
    id integer NOT NULL,
    image character varying,
    name character varying,
    listing_order integer DEFAULT 0,
    imageable_id integer,
    imageable_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_private boolean DEFAULT false NOT NULL
);


--
-- Name: public_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: public_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public_images_id_seq OWNED BY public_images.id;


--
-- Name: rear_gear_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rear_gear_types (
    id integer NOT NULL,
    name character varying,
    count integer,
    internal boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    standard boolean,
    slug character varying
);


--
-- Name: rear_gear_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rear_gear_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rear_gear_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rear_gear_types_id_seq OWNED BY rear_gear_types.id;


--
-- Name: recovery_displays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE recovery_displays (
    id integer NOT NULL,
    stolen_record_id integer,
    quote text,
    quote_by character varying,
    date_recovered timestamp without time zone,
    link character varying,
    image character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: recovery_displays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE recovery_displays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recovery_displays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE recovery_displays_id_seq OWNED BY recovery_displays.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE schema_migrations (
    version character varying NOT NULL
);


--
-- Name: states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE states (
    id integer NOT NULL,
    name character varying,
    abbreviation character varying,
    country_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE states_id_seq OWNED BY states.id;


--
-- Name: stolen_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE stolen_notifications (
    id integer NOT NULL,
    subject character varying,
    message text,
    sender_id integer,
    receiver_id integer,
    bike_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    receiver_email character varying,
    oauth_application_id integer,
    reference_url text,
    send_dates json
);


--
-- Name: stolen_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stolen_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stolen_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stolen_notifications_id_seq OWNED BY stolen_notifications.id;


--
-- Name: stolen_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE stolen_records (
    id integer NOT NULL,
    zipcode character varying,
    city character varying,
    theft_description text,
    "time" text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    bike_id integer,
    current boolean DEFAULT true,
    street character varying,
    latitude double precision,
    longitude double precision,
    date_stolen timestamp without time zone,
    phone character varying,
    phone_for_everyone boolean,
    phone_for_users boolean DEFAULT true,
    phone_for_shops boolean DEFAULT true,
    phone_for_police boolean DEFAULT true,
    police_report_number character varying,
    locking_description character varying,
    lock_defeat_description character varying,
    country_id integer,
    police_report_department character varying,
    state_id integer,
    creation_organization_id integer,
    secondary_phone character varying,
    approved boolean DEFAULT false NOT NULL,
    receive_notifications boolean DEFAULT true,
    proof_of_ownership boolean,
    date_recovered timestamp without time zone,
    recovered_description text,
    index_helped_recovery boolean DEFAULT false NOT NULL,
    can_share_recovery boolean DEFAULT false NOT NULL,
    recovery_posted boolean DEFAULT false,
    recovery_tweet text,
    recovery_share text,
    create_open311 boolean DEFAULT false NOT NULL,
    tsved_at timestamp without time zone,
    estimated_value integer
);


--
-- Name: stolen_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE stolen_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stolen_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE stolen_records_id_seq OWNED BY stolen_records.id;


--
-- Name: user_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE user_emails (
    id integer NOT NULL,
    email character varying,
    user_id integer,
    old_user_id integer,
    confirmation_token text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: user_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_emails_id_seq OWNED BY user_emails.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE users (
    id integer NOT NULL,
    name character varying,
    email character varying,
    password text,
    last_login timestamp without time zone,
    superuser boolean DEFAULT false NOT NULL,
    password_reset_token text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    password_digest character varying,
    banned boolean,
    phone character varying,
    zipcode character varying,
    twitter character varying,
    show_twitter boolean DEFAULT false NOT NULL,
    website character varying,
    show_website boolean DEFAULT false NOT NULL,
    show_phone boolean DEFAULT true,
    show_bikes boolean DEFAULT false NOT NULL,
    username character varying,
    has_stolen_bikes boolean,
    avatar character varying,
    description text,
    title text,
    terms_of_service boolean DEFAULT false NOT NULL,
    vendor_terms_of_service boolean,
    when_vendor_terms_of_service timestamp without time zone,
    confirmed boolean DEFAULT false NOT NULL,
    confirmation_token character varying,
    can_send_many_stolen_notifications boolean DEFAULT false NOT NULL,
    auth_token character varying,
    stripe_id character varying,
    is_paid_member boolean DEFAULT false NOT NULL,
    paid_membership_info text,
    is_content_admin boolean DEFAULT false NOT NULL,
    my_bikes_hash text,
    is_emailable boolean DEFAULT false NOT NULL,
    developer boolean DEFAULT false NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: wheel_sizes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE wheel_sizes (
    id integer NOT NULL,
    name character varying,
    description character varying,
    iso_bsd integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    priority integer
);


--
-- Name: wheel_sizes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE wheel_sizes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wheel_sizes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE wheel_sizes_id_seq OWNED BY wheel_sizes.id;


--
-- Name: ads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY ads ALTER COLUMN id SET DEFAULT nextval('ads_id_seq'::regclass);


--
-- Name: b_params id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY b_params ALTER COLUMN id SET DEFAULT nextval('b_params_id_seq'::regclass);


--
-- Name: bike_organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bike_organizations ALTER COLUMN id SET DEFAULT nextval('bike_organizations_id_seq'::regclass);


--
-- Name: bikes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bikes ALTER COLUMN id SET DEFAULT nextval('bikes_id_seq'::regclass);


--
-- Name: blogs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY blogs ALTER COLUMN id SET DEFAULT nextval('blogs_id_seq'::regclass);


--
-- Name: cgroups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY cgroups ALTER COLUMN id SET DEFAULT nextval('cgroups_id_seq'::regclass);


--
-- Name: colors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY colors ALTER COLUMN id SET DEFAULT nextval('colors_id_seq'::regclass);


--
-- Name: components id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY components ALTER COLUMN id SET DEFAULT nextval('components_id_seq'::regclass);


--
-- Name: countries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY countries ALTER COLUMN id SET DEFAULT nextval('countries_id_seq'::regclass);


--
-- Name: creation_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY creation_states ALTER COLUMN id SET DEFAULT nextval('creation_states_id_seq'::regclass);


--
-- Name: ctypes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY ctypes ALTER COLUMN id SET DEFAULT nextval('ctypes_id_seq'::regclass);


--
-- Name: customer_contacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY customer_contacts ALTER COLUMN id SET DEFAULT nextval('customer_contacts_id_seq'::regclass);


--
-- Name: cycle_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY cycle_types ALTER COLUMN id SET DEFAULT nextval('cycle_types_id_seq'::regclass);


--
-- Name: duplicate_bike_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY duplicate_bike_groups ALTER COLUMN id SET DEFAULT nextval('duplicate_bike_groups_id_seq'::regclass);


--
-- Name: feedbacks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY feedbacks ALTER COLUMN id SET DEFAULT nextval('feedbacks_id_seq'::regclass);


--
-- Name: flavor_texts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY flavor_texts ALTER COLUMN id SET DEFAULT nextval('flavor_texts_id_seq'::regclass);


--
-- Name: frame_materials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY frame_materials ALTER COLUMN id SET DEFAULT nextval('frame_materials_id_seq'::regclass);


--
-- Name: front_gear_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY front_gear_types ALTER COLUMN id SET DEFAULT nextval('front_gear_types_id_seq'::regclass);


--
-- Name: handlebar_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY handlebar_types ALTER COLUMN id SET DEFAULT nextval('handlebar_types_id_seq'::regclass);


--
-- Name: integrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY integrations ALTER COLUMN id SET DEFAULT nextval('integrations_id_seq'::regclass);


--
-- Name: listicles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY listicles ALTER COLUMN id SET DEFAULT nextval('listicles_id_seq'::regclass);


--
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY locations ALTER COLUMN id SET DEFAULT nextval('locations_id_seq'::regclass);


--
-- Name: lock_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY lock_types ALTER COLUMN id SET DEFAULT nextval('lock_types_id_seq'::regclass);


--
-- Name: locks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY locks ALTER COLUMN id SET DEFAULT nextval('locks_id_seq'::regclass);


--
-- Name: mail_snippets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY mail_snippets ALTER COLUMN id SET DEFAULT nextval('mail_snippets_id_seq'::regclass);


--
-- Name: manufacturers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY manufacturers ALTER COLUMN id SET DEFAULT nextval('manufacturers_id_seq'::regclass);


--
-- Name: memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY memberships ALTER COLUMN id SET DEFAULT nextval('memberships_id_seq'::regclass);


--
-- Name: normalized_serial_segments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY normalized_serial_segments ALTER COLUMN id SET DEFAULT nextval('normalized_serial_segments_id_seq'::regclass);


--
-- Name: oauth_access_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_access_grants ALTER COLUMN id SET DEFAULT nextval('oauth_access_grants_id_seq'::regclass);


--
-- Name: oauth_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_access_tokens ALTER COLUMN id SET DEFAULT nextval('oauth_access_tokens_id_seq'::regclass);


--
-- Name: oauth_applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_applications ALTER COLUMN id SET DEFAULT nextval('oauth_applications_id_seq'::regclass);


--
-- Name: organization_deals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization_deals ALTER COLUMN id SET DEFAULT nextval('organization_deals_id_seq'::regclass);


--
-- Name: organization_invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization_invitations ALTER COLUMN id SET DEFAULT nextval('organization_invitations_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY organizations ALTER COLUMN id SET DEFAULT nextval('organizations_id_seq'::regclass);


--
-- Name: other_listings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY other_listings ALTER COLUMN id SET DEFAULT nextval('other_listings_id_seq'::regclass);


--
-- Name: ownerships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY ownerships ALTER COLUMN id SET DEFAULT nextval('ownerships_id_seq'::regclass);


--
-- Name: paints id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY paints ALTER COLUMN id SET DEFAULT nextval('paints_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY payments ALTER COLUMN id SET DEFAULT nextval('payments_id_seq'::regclass);


--
-- Name: propulsion_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY propulsion_types ALTER COLUMN id SET DEFAULT nextval('propulsion_types_id_seq'::regclass);


--
-- Name: public_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public_images ALTER COLUMN id SET DEFAULT nextval('public_images_id_seq'::regclass);


--
-- Name: rear_gear_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY rear_gear_types ALTER COLUMN id SET DEFAULT nextval('rear_gear_types_id_seq'::regclass);


--
-- Name: recovery_displays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY recovery_displays ALTER COLUMN id SET DEFAULT nextval('recovery_displays_id_seq'::regclass);


--
-- Name: states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY states ALTER COLUMN id SET DEFAULT nextval('states_id_seq'::regclass);


--
-- Name: stolen_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY stolen_notifications ALTER COLUMN id SET DEFAULT nextval('stolen_notifications_id_seq'::regclass);


--
-- Name: stolen_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY stolen_records ALTER COLUMN id SET DEFAULT nextval('stolen_records_id_seq'::regclass);


--
-- Name: user_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_emails ALTER COLUMN id SET DEFAULT nextval('user_emails_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: wheel_sizes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY wheel_sizes ALTER COLUMN id SET DEFAULT nextval('wheel_sizes_id_seq'::regclass);


--
-- Name: ads ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY ads
    ADD CONSTRAINT ads_pkey PRIMARY KEY (id);


--
-- Name: b_params b_params_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY b_params
    ADD CONSTRAINT b_params_pkey PRIMARY KEY (id);


--
-- Name: bike_organizations bike_organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bike_organizations
    ADD CONSTRAINT bike_organizations_pkey PRIMARY KEY (id);


--
-- Name: bikes bikes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bikes
    ADD CONSTRAINT bikes_pkey PRIMARY KEY (id);


--
-- Name: blogs blogs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY blogs
    ADD CONSTRAINT blogs_pkey PRIMARY KEY (id);


--
-- Name: cgroups cgroups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cgroups
    ADD CONSTRAINT cgroups_pkey PRIMARY KEY (id);


--
-- Name: colors colors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY colors
    ADD CONSTRAINT colors_pkey PRIMARY KEY (id);


--
-- Name: components components_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY components
    ADD CONSTRAINT components_pkey PRIMARY KEY (id);


--
-- Name: countries countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (id);


--
-- Name: creation_states creation_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY creation_states
    ADD CONSTRAINT creation_states_pkey PRIMARY KEY (id);


--
-- Name: ctypes ctypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY ctypes
    ADD CONSTRAINT ctypes_pkey PRIMARY KEY (id);


--
-- Name: customer_contacts customer_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY customer_contacts
    ADD CONSTRAINT customer_contacts_pkey PRIMARY KEY (id);


--
-- Name: cycle_types cycle_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY cycle_types
    ADD CONSTRAINT cycle_types_pkey PRIMARY KEY (id);


--
-- Name: duplicate_bike_groups duplicate_bike_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY duplicate_bike_groups
    ADD CONSTRAINT duplicate_bike_groups_pkey PRIMARY KEY (id);


--
-- Name: feedbacks feedbacks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY feedbacks
    ADD CONSTRAINT feedbacks_pkey PRIMARY KEY (id);


--
-- Name: flavor_texts flavor_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY flavor_texts
    ADD CONSTRAINT flavor_texts_pkey PRIMARY KEY (id);


--
-- Name: frame_materials frame_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY frame_materials
    ADD CONSTRAINT frame_materials_pkey PRIMARY KEY (id);


--
-- Name: front_gear_types front_gear_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY front_gear_types
    ADD CONSTRAINT front_gear_types_pkey PRIMARY KEY (id);


--
-- Name: handlebar_types handlebar_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY handlebar_types
    ADD CONSTRAINT handlebar_types_pkey PRIMARY KEY (id);


--
-- Name: integrations integrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY integrations
    ADD CONSTRAINT integrations_pkey PRIMARY KEY (id);


--
-- Name: listicles listicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY listicles
    ADD CONSTRAINT listicles_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: lock_types lock_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY lock_types
    ADD CONSTRAINT lock_types_pkey PRIMARY KEY (id);


--
-- Name: locks locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY locks
    ADD CONSTRAINT locks_pkey PRIMARY KEY (id);


--
-- Name: mail_snippets mail_snippets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY mail_snippets
    ADD CONSTRAINT mail_snippets_pkey PRIMARY KEY (id);


--
-- Name: manufacturers manufacturers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY manufacturers
    ADD CONSTRAINT manufacturers_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: normalized_serial_segments normalized_serial_segments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY normalized_serial_segments
    ADD CONSTRAINT normalized_serial_segments_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_grants oauth_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_access_grants
    ADD CONSTRAINT oauth_access_grants_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_tokens oauth_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_access_tokens
    ADD CONSTRAINT oauth_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: oauth_applications oauth_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_applications
    ADD CONSTRAINT oauth_applications_pkey PRIMARY KEY (id);


--
-- Name: organization_deals organization_deals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization_deals
    ADD CONSTRAINT organization_deals_pkey PRIMARY KEY (id);


--
-- Name: organization_invitations organization_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organization_invitations
    ADD CONSTRAINT organization_invitations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: other_listings other_listings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY other_listings
    ADD CONSTRAINT other_listings_pkey PRIMARY KEY (id);


--
-- Name: ownerships ownerships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY ownerships
    ADD CONSTRAINT ownerships_pkey PRIMARY KEY (id);


--
-- Name: paints paints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY paints
    ADD CONSTRAINT paints_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: propulsion_types propulsion_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY propulsion_types
    ADD CONSTRAINT propulsion_types_pkey PRIMARY KEY (id);


--
-- Name: public_images public_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public_images
    ADD CONSTRAINT public_images_pkey PRIMARY KEY (id);


--
-- Name: rear_gear_types rear_gear_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rear_gear_types
    ADD CONSTRAINT rear_gear_types_pkey PRIMARY KEY (id);


--
-- Name: recovery_displays recovery_displays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY recovery_displays
    ADD CONSTRAINT recovery_displays_pkey PRIMARY KEY (id);


--
-- Name: states states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY states
    ADD CONSTRAINT states_pkey PRIMARY KEY (id);


--
-- Name: stolen_notifications stolen_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stolen_notifications
    ADD CONSTRAINT stolen_notifications_pkey PRIMARY KEY (id);


--
-- Name: stolen_records stolen_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY stolen_records
    ADD CONSTRAINT stolen_records_pkey PRIMARY KEY (id);


--
-- Name: user_emails user_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_emails
    ADD CONSTRAINT user_emails_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wheel_sizes wheel_sizes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY wheel_sizes
    ADD CONSTRAINT wheel_sizes_pkey PRIMARY KEY (id);


--
-- Name: index_bike_organizations_on_bike_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bike_organizations_on_bike_id ON bike_organizations USING btree (bike_id);


--
-- Name: index_bike_organizations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bike_organizations_on_organization_id ON bike_organizations USING btree (organization_id);


--
-- Name: index_bikes_on_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_card_id ON bikes USING btree (card_id);


--
-- Name: index_bikes_on_creation_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_creation_state_id ON bikes USING btree (creation_state_id);


--
-- Name: index_bikes_on_current_stolen_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_current_stolen_record_id ON bikes USING btree (current_stolen_record_id);


--
-- Name: index_bikes_on_cycle_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_cycle_type_id ON bikes USING btree (cycle_type_id);


--
-- Name: index_bikes_on_manufacturer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_manufacturer_id ON bikes USING btree (manufacturer_id);


--
-- Name: index_bikes_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_organization_id ON bikes USING btree (creation_organization_id);


--
-- Name: index_bikes_on_paint_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_paint_id ON bikes USING btree (paint_id);


--
-- Name: index_bikes_on_primary_frame_color_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_primary_frame_color_id ON bikes USING btree (primary_frame_color_id);


--
-- Name: index_bikes_on_secondary_frame_color_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_secondary_frame_color_id ON bikes USING btree (secondary_frame_color_id);


--
-- Name: index_bikes_on_stolen_lat_and_stolen_long; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_stolen_lat_and_stolen_long ON bikes USING btree (stolen_lat, stolen_long);


--
-- Name: index_bikes_on_tertiary_frame_color_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_tertiary_frame_color_id ON bikes USING btree (tertiary_frame_color_id);


--
-- Name: index_components_on_bike_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_components_on_bike_id ON components USING btree (bike_id);


--
-- Name: index_components_on_manufacturer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_components_on_manufacturer_id ON components USING btree (manufacturer_id);


--
-- Name: index_creation_states_on_bike_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creation_states_on_bike_id ON creation_states USING btree (bike_id);


--
-- Name: index_creation_states_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creation_states_on_creator_id ON creation_states USING btree (creator_id);


--
-- Name: index_creation_states_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_creation_states_on_organization_id ON creation_states USING btree (organization_id);


--
-- Name: index_integrations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integrations_on_user_id ON integrations USING btree (user_id);


--
-- Name: index_locks_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_locks_on_user_id ON locks USING btree (user_id);


--
-- Name: index_mail_snippets_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mail_snippets_on_organization_id ON mail_snippets USING btree (organization_id);


--
-- Name: index_memberships_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_organization_id ON memberships USING btree (organization_id);


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON memberships USING btree (user_id);


--
-- Name: index_normalized_serial_segments_on_bike_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_normalized_serial_segments_on_bike_id ON normalized_serial_segments USING btree (bike_id);


--
-- Name: index_normalized_serial_segments_on_duplicate_bike_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_normalized_serial_segments_on_duplicate_bike_group_id ON normalized_serial_segments USING btree (duplicate_bike_group_id);


--
-- Name: index_oauth_access_grants_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_grants_on_token ON oauth_access_grants USING btree (token);


--
-- Name: index_oauth_access_tokens_on_refresh_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_refresh_token ON oauth_access_tokens USING btree (refresh_token);


--
-- Name: index_oauth_access_tokens_on_resource_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_access_tokens_on_resource_owner_id ON oauth_access_tokens USING btree (resource_owner_id);


--
-- Name: index_oauth_access_tokens_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_token ON oauth_access_tokens USING btree (token);


--
-- Name: index_oauth_applications_on_owner_id_and_owner_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_applications_on_owner_id_and_owner_type ON oauth_applications USING btree (owner_id, owner_type);


--
-- Name: index_oauth_applications_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_applications_on_uid ON oauth_applications USING btree (uid);


--
-- Name: index_organization_invitations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_organization_invitations_on_organization_id ON organization_invitations USING btree (organization_id);


--
-- Name: index_organizations_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_slug ON organizations USING btree (slug);


--
-- Name: index_ownerships_on_bike_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ownerships_on_bike_id ON ownerships USING btree (bike_id);


--
-- Name: index_ownerships_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ownerships_on_creator_id ON ownerships USING btree (creator_id);


--
-- Name: index_ownerships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ownerships_on_user_id ON ownerships USING btree (user_id);


--
-- Name: index_payments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_user_id ON payments USING btree (user_id);


--
-- Name: index_public_images_on_imageable_id_and_imageable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_public_images_on_imageable_id_and_imageable_type ON public_images USING btree (imageable_id, imageable_type);


--
-- Name: index_recovery_displays_on_stolen_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recovery_displays_on_stolen_record_id ON recovery_displays USING btree (stolen_record_id);


--
-- Name: index_states_on_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_states_on_country_id ON states USING btree (country_id);


--
-- Name: index_stolen_notifications_on_oauth_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stolen_notifications_on_oauth_application_id ON stolen_notifications USING btree (oauth_application_id);


--
-- Name: index_stolen_records_on_bike_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stolen_records_on_bike_id ON stolen_records USING btree (bike_id);


--
-- Name: index_stolen_records_on_latitude_and_longitude; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stolen_records_on_latitude_and_longitude ON stolen_records USING btree (latitude, longitude);


--
-- Name: index_user_emails_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_emails_on_user_id ON user_emails USING btree (user_id);


--
-- Name: index_users_on_password_reset_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_password_reset_token ON users USING btree (password_reset_token);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO schema_migrations (version) VALUES ('20130807222803');

INSERT INTO schema_migrations (version) VALUES ('20130809155956');

INSERT INTO schema_migrations (version) VALUES ('20130820145312');

INSERT INTO schema_migrations (version) VALUES ('20130820150839');

INSERT INTO schema_migrations (version) VALUES ('20130820173657');

INSERT INTO schema_migrations (version) VALUES ('20130821134559');

INSERT INTO schema_migrations (version) VALUES ('20130821135549');

INSERT INTO schema_migrations (version) VALUES ('20130821230157');

INSERT INTO schema_migrations (version) VALUES ('20130903142657');

INSERT INTO schema_migrations (version) VALUES ('20130905215302');

INSERT INTO schema_migrations (version) VALUES ('20131009140156');

INSERT INTO schema_migrations (version) VALUES ('20131013171704');

INSERT INTO schema_migrations (version) VALUES ('20131013172625');

INSERT INTO schema_migrations (version) VALUES ('20131013233351');

INSERT INTO schema_migrations (version) VALUES ('20131018221510');

INSERT INTO schema_migrations (version) VALUES ('20131029004416');

INSERT INTO schema_migrations (version) VALUES ('20131029144536');

INSERT INTO schema_migrations (version) VALUES ('20131030132116');

INSERT INTO schema_migrations (version) VALUES ('20131030161105');

INSERT INTO schema_migrations (version) VALUES ('20131031222251');

INSERT INTO schema_migrations (version) VALUES ('20131101002019');

INSERT INTO schema_migrations (version) VALUES ('20131105010837');

INSERT INTO schema_migrations (version) VALUES ('20131117232341');

INSERT INTO schema_migrations (version) VALUES ('20131202181502');

INSERT INTO schema_migrations (version) VALUES ('20131204230644');

INSERT INTO schema_migrations (version) VALUES ('20131205145316');

INSERT INTO schema_migrations (version) VALUES ('20131211163130');

INSERT INTO schema_migrations (version) VALUES ('20131212161639');

INSERT INTO schema_migrations (version) VALUES ('20131213185845');

INSERT INTO schema_migrations (version) VALUES ('20131216154423');

INSERT INTO schema_migrations (version) VALUES ('20131218201839');

INSERT INTO schema_migrations (version) VALUES ('20131219182417');

INSERT INTO schema_migrations (version) VALUES ('20131221193910');

INSERT INTO schema_migrations (version) VALUES ('20131227132337');

INSERT INTO schema_migrations (version) VALUES ('20131227133553');

INSERT INTO schema_migrations (version) VALUES ('20131227135813');

INSERT INTO schema_migrations (version) VALUES ('20131227151833');

INSERT INTO schema_migrations (version) VALUES ('20131229194508');

INSERT INTO schema_migrations (version) VALUES ('20140103144654');

INSERT INTO schema_migrations (version) VALUES ('20140103161433');

INSERT INTO schema_migrations (version) VALUES ('20140103222943');

INSERT INTO schema_migrations (version) VALUES ('20140103235111');

INSERT INTO schema_migrations (version) VALUES ('20140104011352');

INSERT INTO schema_migrations (version) VALUES ('20140105181220');

INSERT INTO schema_migrations (version) VALUES ('20140106031356');

INSERT INTO schema_migrations (version) VALUES ('20140108195016');

INSERT INTO schema_migrations (version) VALUES ('20140108202025');

INSERT INTO schema_migrations (version) VALUES ('20140108203313');

INSERT INTO schema_migrations (version) VALUES ('20140109001625');

INSERT INTO schema_migrations (version) VALUES ('20140111142521');

INSERT INTO schema_migrations (version) VALUES ('20140111183125');

INSERT INTO schema_migrations (version) VALUES ('20140112004042');

INSERT INTO schema_migrations (version) VALUES ('20140113181408');

INSERT INTO schema_migrations (version) VALUES ('20140114230221');

INSERT INTO schema_migrations (version) VALUES ('20140115041923');

INSERT INTO schema_migrations (version) VALUES ('20140116214759');

INSERT INTO schema_migrations (version) VALUES ('20140116222529');

INSERT INTO schema_migrations (version) VALUES ('20140122181025');

INSERT INTO schema_migrations (version) VALUES ('20140122181308');

INSERT INTO schema_migrations (version) VALUES ('20140204162239');

INSERT INTO schema_migrations (version) VALUES ('20140225203114');

INSERT INTO schema_migrations (version) VALUES ('20140227225103');

INSERT INTO schema_migrations (version) VALUES ('20140301174242');

INSERT INTO schema_migrations (version) VALUES ('20140312191710');

INSERT INTO schema_migrations (version) VALUES ('20140313002428');

INSERT INTO schema_migrations (version) VALUES ('20140426211337');

INSERT INTO schema_migrations (version) VALUES ('20140504234957');

INSERT INTO schema_migrations (version) VALUES ('20140507023948');

INSERT INTO schema_migrations (version) VALUES ('20140510155037');

INSERT INTO schema_migrations (version) VALUES ('20140510163446');

INSERT INTO schema_migrations (version) VALUES ('20140523122545');

INSERT INTO schema_migrations (version) VALUES ('20140524183616');

INSERT INTO schema_migrations (version) VALUES ('20140525163552');

INSERT INTO schema_migrations (version) VALUES ('20140525173416');

INSERT INTO schema_migrations (version) VALUES ('20140525183759');

INSERT INTO schema_migrations (version) VALUES ('20140526141810');

INSERT INTO schema_migrations (version) VALUES ('20140526161223');

INSERT INTO schema_migrations (version) VALUES ('20140614190845');

INSERT INTO schema_migrations (version) VALUES ('20140615230212');

INSERT INTO schema_migrations (version) VALUES ('20140621013108');

INSERT INTO schema_migrations (version) VALUES ('20140621171727');

INSERT INTO schema_migrations (version) VALUES ('20140629144444');

INSERT INTO schema_migrations (version) VALUES ('20140629162651');

INSERT INTO schema_migrations (version) VALUES ('20140629170842');

INSERT INTO schema_migrations (version) VALUES ('20140706170329');

INSERT INTO schema_migrations (version) VALUES ('20140713182107');

INSERT INTO schema_migrations (version) VALUES ('20140720175226');

INSERT INTO schema_migrations (version) VALUES ('20140809102725');

INSERT INTO schema_migrations (version) VALUES ('20140817160101');

INSERT INTO schema_migrations (version) VALUES ('20140830152248');

INSERT INTO schema_migrations (version) VALUES ('20140902230041');

INSERT INTO schema_migrations (version) VALUES ('20140903191321');

INSERT INTO schema_migrations (version) VALUES ('20140907144150');

INSERT INTO schema_migrations (version) VALUES ('20140916141534');

INSERT INTO schema_migrations (version) VALUES ('20140916185511');

INSERT INTO schema_migrations (version) VALUES ('20141006184444');

INSERT INTO schema_migrations (version) VALUES ('20141008160942');

INSERT INTO schema_migrations (version) VALUES ('20141010145930');

INSERT INTO schema_migrations (version) VALUES ('20141025185722');

INSERT INTO schema_migrations (version) VALUES ('20141026172449');

INSERT INTO schema_migrations (version) VALUES ('20141030140601');

INSERT INTO schema_migrations (version) VALUES ('20141031152955');

INSERT INTO schema_migrations (version) VALUES ('20141105172149');

INSERT INTO schema_migrations (version) VALUES ('20141110174307');

INSERT INTO schema_migrations (version) VALUES ('20141210002148');

INSERT INTO schema_migrations (version) VALUES ('20141210031732');

INSERT INTO schema_migrations (version) VALUES ('20141210233551');

INSERT INTO schema_migrations (version) VALUES ('20141217191826');

INSERT INTO schema_migrations (version) VALUES ('20141217200937');

INSERT INTO schema_migrations (version) VALUES ('20141224165646');

INSERT INTO schema_migrations (version) VALUES ('20141231170329');

INSERT INTO schema_migrations (version) VALUES ('20150111193842');

INSERT INTO schema_migrations (version) VALUES ('20150111211009');

INSERT INTO schema_migrations (version) VALUES ('20150122195921');

INSERT INTO schema_migrations (version) VALUES ('20150123233624');

INSERT INTO schema_migrations (version) VALUES ('20150127220842');

INSERT INTO schema_migrations (version) VALUES ('20150208001048');

INSERT INTO schema_migrations (version) VALUES ('20150321233527');

INSERT INTO schema_migrations (version) VALUES ('20150325145515');

INSERT INTO schema_migrations (version) VALUES ('20150402051334');

INSERT INTO schema_migrations (version) VALUES ('20150507222158');

INSERT INTO schema_migrations (version) VALUES ('20150518192613');

INSERT INTO schema_migrations (version) VALUES ('20150701151619');

INSERT INTO schema_migrations (version) VALUES ('20150805160333');

INSERT INTO schema_migrations (version) VALUES ('20150903194549');

INSERT INTO schema_migrations (version) VALUES ('20150916133842');

INSERT INTO schema_migrations (version) VALUES ('20151122175408');

INSERT INTO schema_migrations (version) VALUES ('20160314144745');

INSERT INTO schema_migrations (version) VALUES ('20160317183354');

INSERT INTO schema_migrations (version) VALUES ('20160320154610');

INSERT INTO schema_migrations (version) VALUES ('20160406180845');

INSERT INTO schema_migrations (version) VALUES ('20160406202125');

INSERT INTO schema_migrations (version) VALUES ('20160408192902');

INSERT INTO schema_migrations (version) VALUES ('20160425185052');

INSERT INTO schema_migrations (version) VALUES ('20160509110049');

INSERT INTO schema_migrations (version) VALUES ('20160509120017');

INSERT INTO schema_migrations (version) VALUES ('20160529093040');

INSERT INTO schema_migrations (version) VALUES ('20160614112308');

INSERT INTO schema_migrations (version) VALUES ('20160629152210');

INSERT INTO schema_migrations (version) VALUES ('20160630161603');

INSERT INTO schema_migrations (version) VALUES ('20160630175602');

INSERT INTO schema_migrations (version) VALUES ('20160631175602');

INSERT INTO schema_migrations (version) VALUES ('20160711183247');

INSERT INTO schema_migrations (version) VALUES ('20160714182030');

INSERT INTO schema_migrations (version) VALUES ('20160808133129');

INSERT INTO schema_migrations (version) VALUES ('20160813191639');

INSERT INTO schema_migrations (version) VALUES ('20160901175004');

INSERT INTO schema_migrations (version) VALUES ('20160910174549');

INSERT INTO schema_migrations (version) VALUES ('20160910184053');

INSERT INTO schema_migrations (version) VALUES ('20160913155615');

INSERT INTO schema_migrations (version) VALUES ('20160923180542');

INSERT INTO schema_migrations (version) VALUES ('20160923215650');

INSERT INTO schema_migrations (version) VALUES ('20161222154603');

INSERT INTO schema_migrations (version) VALUES ('20170227012150');

INSERT INTO schema_migrations (version) VALUES ('20170503024611');


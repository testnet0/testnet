-- ============================================================
-- TestNet PostgreSQL 初始化脚本
-- 从 testnet.sql (MySQL) 自动转换 + 手工校正
-- 适用于 PostgreSQL 14+
-- ============================================================

-- 启用 pgcrypto 扩展（用于 gen_random_uuid()）
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 注册 smallint 与 boolean 隐式类型比较操作符
DROP OPERATOR IF EXISTS = (smallint, boolean);
DROP OPERATOR IF EXISTS = (boolean, smallint);
DROP OPERATOR IF EXISTS <> (smallint, boolean);
DROP OPERATOR IF EXISTS <> (boolean, smallint);

CREATE OR REPLACE FUNCTION int2_eq_bool(i smallint, b boolean) RETURNS boolean AS $$
    SELECT (i = 1) = b;
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OPERATOR = (
    LEFTARG = smallint,
    RIGHTARG = boolean,
    PROCEDURE = int2_eq_bool,
    COMMUTATOR = =
);

CREATE OR REPLACE FUNCTION bool_eq_int2(b boolean, i smallint) RETURNS boolean AS $$
    SELECT b = (i = 1);
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OPERATOR = (
    LEFTARG = boolean,
    RIGHTARG = smallint,
    PROCEDURE = bool_eq_int2,
    COMMUTATOR = =
);

CREATE OR REPLACE FUNCTION int2_ne_bool(i smallint, b boolean) RETURNS boolean AS $$
    SELECT (i = 1) <> b;
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OPERATOR <> (
    LEFTARG = smallint,
    RIGHTARG = boolean,
    PROCEDURE = int2_ne_bool,
    COMMUTATOR = <>
);

CREATE OR REPLACE FUNCTION bool_ne_int2(b boolean, i smallint) RETURNS boolean AS $$
    SELECT b <> (i = 1);
$$ LANGUAGE SQL IMMUTABLE STRICT;

CREATE OPERATOR <> (
    LEFTARG = boolean,
    RIGHTARG = smallint,
    PROCEDURE = bool_ne_int2,
    COMMUTATOR = <>
);



DROP TABLE IF EXISTS sys_department CASCADE;

CREATE TABLE IF NOT EXISTS sys_department (
    id varchar(64) NOT NULL,
    parent_id varchar(64) DEFAULT 0,
    department_name varchar(100) NOT NULL,
    department_code varchar(64) DEFAULT NULL,
    sort_order int DEFAULT 0,
    leader varchar(64) DEFAULT NULL,
    phone varchar(20) DEFAULT NULL,
    email varchar(100) DEFAULT NULL,
    status varchar(20) DEFAULT 'ACTIVE',
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    children jsonb DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_sys_department_parent_id ON sys_department (parent_id);
CREATE INDEX IF NOT EXISTS idx_sys_department_department_code ON sys_department (department_code);

DROP TABLE IF EXISTS sys_permission CASCADE;

CREATE TABLE IF NOT EXISTS sys_permission (
    id varchar(64) NOT NULL,
    menu_id varchar(64) DEFAULT 0,
    permission_code varchar(100) NOT NULL,
    permission_name varchar(100) NOT NULL,
    resource_type varchar(20) DEFAULT NULL,
    path varchar(255) DEFAULT NULL,
    component varchar(255) DEFAULT NULL,
    icon varchar(64) DEFAULT NULL,
    sort_order int DEFAULT 0,
    status varchar(20) DEFAULT 'ACTIVE',
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    children jsonb DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS permission_code ON sys_permission (permission_code);
CREATE INDEX IF NOT EXISTS idx_sys_permission_menu_id ON sys_permission (menu_id);

DROP TABLE IF EXISTS sys_role CASCADE;

CREATE TABLE IF NOT EXISTS sys_role (
    id varchar(64) NOT NULL,
    role_code varchar(64) NOT NULL,
    role_name varchar(100) NOT NULL,
    description varchar(500) DEFAULT NULL,
    sort_order int DEFAULT 0,
    status varchar(20) DEFAULT 'ACTIVE',
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    permission_ids jsonb DEFAULT NULL,
    permissions jsonb DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS role_code ON sys_role (role_code);

DROP TABLE IF EXISTS sys_role_permission CASCADE;

CREATE TABLE IF NOT EXISTS sys_role_permission (
    id varchar(64) NOT NULL,
    role_id varchar(64) NOT NULL,
    permission_id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_role_permission ON sys_role_permission (role_id, permission_id);
CREATE INDEX IF NOT EXISTS idx_sys_role_permission_role_id ON sys_role_permission (role_id);
CREATE INDEX IF NOT EXISTS idx_sys_role_permission_permission_id ON sys_role_permission (permission_id);

DROP TABLE IF EXISTS sys_config CASCADE;

CREATE TABLE sys_config (
    id varchar(64) NOT NULL,
    config_key varchar(128) NOT NULL,
    config_value text,
    config_name varchar(128) NOT NULL,
    config_group varchar(64) DEFAULT 'DEFAULT',
    config_type varchar(64) DEFAULT 'string',
    description varchar(500) DEFAULT NULL,
    is_system smallint DEFAULT 0,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_config_key ON sys_config (config_key);

INSERT INTO
    sys_config (
        id,
        config_key,
        config_value,
        config_name,
        config_group,
        config_type,
        description,
        is_system
    )
VALUES (
        'sys-mail-enabled',
        'sys.notification.email.enabled',
        'false',
        '邮件通知开关',
        'EMAIL',
        'boolean',
        '是否启用邮件通知功能',
        1
    ),
    (
        'sys-mail-host',
        'sys.mail.host',
        '',
        'SMTP服务器',
        'EMAIL',
        'string',
        'SMTP服务器地址',
        1
    ),
    (
        'sys-mail-port',
        'sys.mail.port',
        '25',
        'SMTP端口',
        'EMAIL',
        'number',
        'SMTP服务器端口',
        1
    ),
    (
        'sys-mail-username',
        'sys.mail.username',
        '',
        '用户名',
        'EMAIL',
        'string',
        'SMTP用户名',
        1
    ),
    (
        'sys-mail-password',
        'sys.mail.password',
        '',
        '密码',
        'EMAIL',
        'string',
        'SMTP密码',
        1
    ),
    (
        'sys-mail-ssl',
        'sys.mail.ssl',
        'false',
        '启用SSL',
        'EMAIL',
        'boolean',
        '是否启用SSL加密',
        1
    ),
    (
        'sys-mail-from',
        'sys.mail.from',
        '',
        '发件人地址',
        'EMAIL',
        'string',
        '发件人邮箱地址',
        1
    ),
    (
        'sys-storage-type',
        'sys.storage.type',
        'LOCAL',
        '存储类型',
        'STORAGE',
        'string',
        '存储类型: LOCAL/MINIO/S3/OSS',
        1
    ),
    (
        'sys-storage-local-path',
        'sys.storage.localPath',
        '/app/uploads',
        '本地存储路径',
        'STORAGE',
        'string',
        '本地存储模式下文件存储路径',
        1
    ),
    (
        'sys-storage-endpoint',
        'sys.storage.endpoint',
        '',
        'S3端点',
        'STORAGE',
        'string',
        'S3/MinIO/OSS 服务端点地址',
        1
    ),
    (
        'sys-storage-access-key',
        'sys.storage.accessKey',
        '',
        'Access Key',
        'STORAGE',
        'string',
        'S3/MinIO/OSS 访问密钥',
        1
    ),
    (
        'sys-storage-secret-key',
        'sys.storage.secretKey',
        '',
        'Secret Key',
        'STORAGE',
        'string',
        'S3/MinIO/OSS 密钥',
        1
    ),
    (
        'sys-storage-bucket',
        'sys.storage.bucket',
        '',
        '存储桶',
        'STORAGE',
        'string',
        'S3/MinIO/OSS 存储桶名称',
        1
    ),
    (
        'sys-storage-region',
        'sys.storage.region',
        'auto',
        '区域',
        'STORAGE',
        'string',
        'S3/MinIO/OSS 区域',
        1
    ),
    (
        'sys-registry-url',
        'sys.registry.url',
        'https://cnb.cool/testnet0/registry/-/git/raw/main',
        'Registry 地址',
        'REGISTRY',
        'string',
        '工具和工作流在线商店地址',
        0
    ),
    (
        'sys-registry-auth-type',
        'sys.registry.auth_type',
        'NONE',
        '认证方式',
        'REGISTRY',
        'string',
        'Registry 认证方式 (NONE/TOKEN/BASIC)',
        0
    ),
    (
        'sys-registry-auth-token',
        'sys.registry.auth_token',
        '',
        'Token 凭证',
        'REGISTRY',
        'string',
        'TOKEN 认证方式的凭证',
        0
    ),
    (
        'sys-registry-auth-username',
        'sys.registry.auth_username',
        '',
        'Basic 用户名',
        'REGISTRY',
        'string',
        'BASIC 认证方式的用户名',
        0
    ),
    (
        'sys-registry-auth-password',
        'sys.registry.auth_password',
        '',
        'Basic 密码',
        'REGISTRY',
        'string',
        'BASIC 认证方式的密码',
        0
    ),
    (
        'sys-temp-cleanup-enabled',
        'sys.temp.cleanup.enabled',
        'true',
        '启用清理',
        'TEMP_CLEANUP',
        'boolean',
        '是否启用临时文件自动清理',
        1
    ),
    (
        'sys-temp-cleanup-retention',
        'sys.temp.cleanup.retentionHours',
        '24',
        '保留时间',
        'TEMP_CLEANUP',
        'number',
        '临时文件保留时间（小时）',
        1
    ),
    (
        'sys-temp-cleanup-directories',
        'sys.temp.cleanup.directories',
        '/tmp/testnet/,/tmp/',
        '清理目录',
        'TEMP_CLEANUP',
        'string',
        '临时文件清理目录（多个用逗号分隔）',
        1
    ),
    (
        'sys-temp-cleanup-patterns',
        'sys.temp.cleanup.patterns',
        'batch_*.txt,targets_*.txt',
        '文件匹配模式',
        'TEMP_CLEANUP',
        'string',
        '临时文件匹配模式（多个用逗号分隔）',
        1
    )
ON CONFLICT DO NOTHING;

DROP TABLE IF EXISTS testnet_project CASCADE;

CREATE TABLE IF NOT EXISTS testnet_project (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    project_name varchar(255) NOT NULL,
    address varchar(255) DEFAULT NULL,
    level int DEFAULT 0,
    comment varchar(1024) DEFAULT NULL,
    mail varchar(64) DEFAULT NULL,
    weibo_link varchar(256) DEFAULT NULL,
    wechat varchar(128) DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    sys_org_code varchar(64) DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_project_project_name ON testnet_project (project_name);




DROP TABLE IF EXISTS sys_user CASCADE;

CREATE TABLE IF NOT EXISTS sys_user (
    id varchar(64) NOT NULL,
    username varchar(64) NOT NULL,
    password varchar(255) NOT NULL,
    real_name varchar(64) DEFAULT NULL,
    email varchar(100) DEFAULT NULL,
    phone varchar(20) DEFAULT NULL,
    department_id varchar(64) DEFAULT NULL,
    position varchar(100) DEFAULT NULL,
    avatar varchar(500) DEFAULT NULL,
    status varchar(20) DEFAULT 'ACTIVE',
    last_login_time timestamp DEFAULT NULL,
    last_login_ip varchar(64) DEFAULT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    role_ids jsonb DEFAULT NULL,
    roles jsonb DEFAULT NULL,
    department_name varchar(255) DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS username ON sys_user (username);
CREATE INDEX IF NOT EXISTS idx_sys_user_department_id ON sys_user (department_id);
CREATE INDEX IF NOT EXISTS idx_sys_user_status ON sys_user (status);

DROP TABLE IF EXISTS sys_user_role CASCADE;

CREATE TABLE IF NOT EXISTS sys_user_role (
    id varchar(64) NOT NULL,
    user_id varchar(64) NOT NULL,
    role_id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_user_role ON sys_user_role (user_id, role_id);
CREATE INDEX IF NOT EXISTS idx_sys_user_role_user_id ON sys_user_role (user_id);
CREATE INDEX IF NOT EXISTS idx_sys_user_role_role_id ON sys_user_role (role_id);


DROP TABLE IF EXISTS testnet_asset_change_log CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_change_log (
    id varchar(64) NOT NULL,
    asset_type varchar(64) NOT NULL,
    asset_id varchar(64) NOT NULL,
    change_type varchar(20) NOT NULL,
    old_value jsonb DEFAULT NULL,
    new_value jsonb DEFAULT NULL,
    source_type varchar(64) DEFAULT NULL,
    source_id varchar(64) DEFAULT NULL,
    changed_by varchar(64) DEFAULT NULL,
    changed_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    create_time timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_testnet_asset_change_log_asset ON testnet_asset_change_log (asset_type, asset_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_change_log_source ON testnet_asset_change_log (source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_change_log_changed_at ON testnet_asset_change_log (changed_at);

DROP TABLE IF EXISTS testnet_asset_company CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_company (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    company_name varchar(255) DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    parent_id varchar(64) DEFAULT NULL,
    has_child smallint DEFAULT 0,
    source varchar(255) DEFAULT 'MANUAL',
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    comment varchar(1024) DEFAULT NULL,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    custom_fields jsonb DEFAULT NULL,
    version int DEFAULT 1,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_company_name_project ON testnet_asset_company (company_name, project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_company_tac_parent_id ON testnet_asset_company (parent_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_company_project ON testnet_asset_company (project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_company_status ON testnet_asset_company (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_company_last_verified ON testnet_asset_company (last_verified);

-- 插入公司样例数据
INSERT INTO testnet_asset_company (
    id,
    company_name,
    project_id,
    parent_id,
    has_child,
    source,
    asset_label,
    create_time,
    status
) VALUES (
    'comp_root',
    '北京测试网联科技有限公司',
    'proj_prod',
    NULL,
    1,
    'MANUAL',
    'tag-partner',
    NOW(),
    'ACTIVE'
), (
    'comp_dev',
    '测试网联研发中心',
    'proj_prod',
    'comp_root',
    0,
    'MANUAL',
    'tag-dev-domain',
    NOW(),
    'ACTIVE'
), (
    'comp_overseas',
    '测试网联海外事业部',
    'proj_prod',
    'comp_root',
    0,
    'MANUAL',
    'tag-prod-domain',
    NOW(),
    'ACTIVE'
)
ON CONFLICT DO NOTHING;

DROP TABLE IF EXISTS testnet_asset_config CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_config (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    config_type varchar(64) NOT NULL,
    name varchar(255) NOT NULL,
    config_key varchar(128) DEFAULT NULL,
    target_type varchar(64) DEFAULT NULL,
    scope_type varchar(64) DEFAULT NULL,
    effect_type varchar(64) DEFAULT NULL,
    matcher_type varchar(64) DEFAULT NULL,
    matcher_value varchar(512) DEFAULT NULL,
    tags varchar(512) DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    company_id varchar(64) DEFAULT NULL,
    owner varchar(128) DEFAULT NULL,
    department varchar(128) DEFAULT NULL,
    recipients varchar(512) DEFAULT NULL,
    color varchar(64) DEFAULT NULL,
    sort_order int DEFAULT 0,
    extra_config text,
    notes varchar(512) DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    version int DEFAULT 0,
    effective_project_ids varchar(255) DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_testnet_asset_config_asset_config_type ON testnet_asset_config (config_type);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_config_asset_config_status ON testnet_asset_config (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_config_asset_config_target ON testnet_asset_config (target_type);

DROP TABLE IF EXISTS testnet_asset_custom_field CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_custom_field (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    asset_type varchar(64) NOT NULL,
    field_name varchar(128) NOT NULL,
    field_label varchar(255) NOT NULL,
    field_type varchar(32) NOT NULL,
    options text DEFAULT NULL,
    default_value varchar(500) DEFAULT NULL,
    required smallint DEFAULT 0,
    sort_order int DEFAULT 0,
    description varchar(500) DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    is_deleted smallint DEFAULT 0,
    version int DEFAULT 1,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_asset_type_field_name ON testnet_asset_custom_field (asset_type, field_name);

DROP TABLE IF EXISTS testnet_asset_domain CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_domain (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    domain varchar(255) DEFAULT NULL,
    icp_number varchar(255) DEFAULT NULL,
    whois varchar(255) DEFAULT NULL,
    company_id varchar(64) DEFAULT NULL,
    source varchar(255) DEFAULT NULL,
    dns_server varchar(1000) DEFAULT NULL,
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    comment varchar(1024) DEFAULT NULL,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    custom_fields jsonb DEFAULT NULL,
    version int DEFAULT 1,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_domain_domain_project ON testnet_asset_domain (domain, project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_domain_project_id ON testnet_asset_domain (project_id);
CREATE INDEX IF NOT EXISTS fk_company_id ON testnet_asset_domain (company_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_domain_status ON testnet_asset_domain (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_domain_last_verified ON testnet_asset_domain (last_verified);

DROP TABLE IF EXISTS testnet_asset_ip CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_ip (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    ip varchar(64) DEFAULT NULL,
    is_public smallint DEFAULT NULL,
    is_ipv6 smallint DEFAULT NULL,
    isp varchar(255) DEFAULT NULL,
    province varchar(255) DEFAULT NULL,
    city varchar(255) DEFAULT NULL,
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    source varchar(255) DEFAULT 'MANUAL',
    country varchar(255) DEFAULT NULL,
    region varchar(255) DEFAULT NULL,
    comment varchar(1024) DEFAULT NULL,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    custom_fields jsonb DEFAULT NULL,
    version int DEFAULT 1,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_ip_ip_project ON testnet_asset_ip (ip, project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_project ON testnet_asset_ip (project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_ip ON testnet_asset_ip (ip);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_status ON testnet_asset_ip (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_last_verified ON testnet_asset_ip (last_verified);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_isp ON testnet_asset_ip (isp);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_province ON testnet_asset_ip (province);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_project_create_time ON testnet_asset_ip (project_id, create_time);

DROP TABLE IF EXISTS testnet_asset_ip_sub_domain CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_ip_sub_domain (
    id varchar(64) NOT NULL,
    subdomain_id varchar(64) DEFAULT NULL,
    ip_id varchar(64) DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS unique_subdomain_ip ON testnet_asset_ip_sub_domain (subdomain_id, ip_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_sub_domain_ip ON testnet_asset_ip_sub_domain (ip_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_ip_sub_domain_domain ON testnet_asset_ip_sub_domain (subdomain_id);

DROP TABLE IF EXISTS testnet_asset_port CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_port (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    port int DEFAULT NULL CHECK (port >= 1 AND port <= 65535),
    is_open smallint DEFAULT NULL,
    ip_id varchar(64) DEFAULT NULL,
    service varchar(128) DEFAULT NULL,
    version_str varchar(128) DEFAULT NULL,
    banner varchar(512) DEFAULT NULL,
    is_web smallint DEFAULT NULL,
    source varchar(128) DEFAULT NULL,
    protocol varchar(128) DEFAULT NULL,
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    product varchar(512) DEFAULT NULL,
    comment varchar(1024) DEFAULT NULL,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    custom_fields jsonb DEFAULT NULL,
    version int DEFAULT 1,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_port_project_ip_port ON testnet_asset_port (project_id, ip_id, port);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_port_project ON testnet_asset_port (project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_port_ip_id_port ON testnet_asset_port (ip_id, port);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_port_status ON testnet_asset_port (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_port_last_verified ON testnet_asset_port (last_verified);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_port_service ON testnet_asset_port (service);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_port_project_port ON testnet_asset_port (project_id, port);

DROP TABLE IF EXISTS testnet_asset_root_domain CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_root_domain (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    domain varchar(255) NOT NULL,
    domain_normalized varchar(255) GENERATED ALWAYS AS (
        lower(
            trim(
                trailing '.'
                from domain
            )
        )
    ) STORED,
    status varchar(64) DEFAULT 'ACTIVE',
    version int DEFAULT 0,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_root_domain_root_domain ON testnet_asset_root_domain (domain);
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_root_domain_root_domain_norm ON testnet_asset_root_domain (domain_normalized);

DROP TABLE IF EXISTS testnet_asset_search_engine CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_search_engine (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    sys_org_code varchar(64) DEFAULT NULL,
    engine_name varchar(64) DEFAULT NULL,
    engine_type varchar(64) DEFAULT 'fofa',
    engine_token varchar(256) DEFAULT NULL,
    engine_host varchar(1024) DEFAULT NULL,
    engine_headers text DEFAULT NULL,
    status varchar(20) DEFAULT 'ACTIVE',
    sort_order int DEFAULT 100,
    default_page_size int DEFAULT 100,
    PRIMARY KEY (id)
);

DROP TABLE IF EXISTS testnet_asset_sub_domain CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_sub_domain (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    sub_domain varchar(255) NOT NULL,
    type varchar(64) DEFAULT NULL,
    dns_record varchar(255) DEFAULT NULL,
    name_server varchar(255) DEFAULT NULL,
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    level int DEFAULT NULL,
    domain_id varchar(64) DEFAULT NULL,
    source varchar(255) DEFAULT 'MANUAL',
    project_id varchar(64) DEFAULT NULL,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    custom_fields jsonb DEFAULT NULL,
    version int DEFAULT 1,
    comment varchar(1024) DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_sub_domain_sub_domain ON testnet_asset_sub_domain (sub_domain, project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_sub_domain_domain ON testnet_asset_sub_domain (domain_id);
CREATE INDEX IF NOT EXISTS fk_project_id_sub_domain ON testnet_asset_sub_domain (project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_sub_domain_status ON testnet_asset_sub_domain (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_sub_domain_last_verified ON testnet_asset_sub_domain (last_verified);

DROP TABLE IF EXISTS testnet_asset_task CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_task (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    job_id varchar(64) DEFAULT NULL,
    owner_type varchar(64) DEFAULT NULL,
    run_id varchar(200) DEFAULT NULL,
    client_id varchar(64) DEFAULT NULL,
    node_id varchar(100) DEFAULT NULL,
    tool_ref varchar(100) DEFAULT NULL,
    input_channel varchar(100) DEFAULT NULL,
    input_params jsonb DEFAULT NULL,
    execution_spec jsonb DEFAULT NULL,
    output_config jsonb DEFAULT NULL,
    task_status varchar(64) DEFAULT NULL,
    task_output text,
    error_message text,
    source_asset_id varchar(100) DEFAULT NULL,
    source_asset_type varchar(64) DEFAULT NULL,
    params_hash varchar(64) DEFAULT NULL,
    dedupe_key varchar(128) DEFAULT NULL,
    contract_version varchar(16) DEFAULT '1.1.0',
    scheduled_time timestamp DEFAULT NULL,
    ai_summary text,
    ai_risk_level varchar(20) DEFAULT NULL,
    timeout_at timestamp DEFAULT NULL,
    retry_count int DEFAULT 0,
    max_retries int DEFAULT 0,
    last_retry_time timestamp DEFAULT NULL,
    parent_task_id varchar(64) DEFAULT NULL,
    session_id varchar(64) DEFAULT NULL,
    tool_name varchar(100) DEFAULT NULL,
    target_value varchar(255) DEFAULT NULL,
    trace_id varchar(64) DEFAULT NULL,
    trigger_source varchar(64) DEFAULT NULL,
    input_asset_type varchar(64) DEFAULT NULL,
    output_asset_type varchar(64) DEFAULT NULL,
    origin_asset_ids jsonb DEFAULT NULL,
    target_asset_mapping jsonb DEFAULT NULL,
    target_field varchar(64) DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_task_job_dedupe ON testnet_asset_task (job_id, dedupe_key);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_project ON testnet_asset_task (project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_job ON testnet_asset_task (job_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_run_id ON testnet_asset_task (run_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_status_create_time ON testnet_asset_task (task_status, create_time);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_client_id ON testnet_asset_task (client_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_timeout_at ON testnet_asset_task (task_status, timeout_at);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_retry ON testnet_asset_task (task_status, retry_count, max_retries, last_retry_time);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_parent_task ON testnet_asset_task (parent_task_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_project_hash_status ON testnet_asset_task (project_id, params_hash, task_status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_ai_risk_level ON testnet_asset_task (ai_risk_level);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_task_scheduled_time ON testnet_asset_task (scheduled_time);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_output_asset_type ON testnet_asset_task (output_asset_type);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_node_id ON testnet_asset_task (run_id, node_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_tool_ref ON testnet_asset_task (tool_ref);

DROP TABLE IF EXISTS testnet_test_case CASCADE;

CREATE TABLE IF NOT EXISTS testnet_test_case (
    id varchar(64) NOT NULL,
    name varchar(255) NOT NULL,
    description varchar(512) DEFAULT NULL,
    type varchar(20) NOT NULL,
    target_id varchar(64) NOT NULL,
    input jsonb DEFAULT NULL,
    assertions jsonb DEFAULT NULL,
    mock_output text,
    status varchar(20) DEFAULT 'ACTIVE',
    created_at timestamp DEFAULT NULL,
    updated_at timestamp DEFAULT NULL,
    is_deleted boolean DEFAULT false,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_testcase_target ON testnet_test_case (target_id);

DROP TABLE IF EXISTS testnet_test_run CASCADE;

CREATE TABLE IF NOT EXISTS testnet_test_run (
    id varchar(64) NOT NULL,
    test_case_id varchar(64) NOT NULL,
    status varchar(20) NOT NULL,
    mock_result jsonb DEFAULT NULL,
    parsed_results jsonb DEFAULT NULL,
    assertion_results jsonb DEFAULT NULL,
    failed_assertion jsonb DEFAULT NULL,
    error_message text,
    started_at timestamp DEFAULT NULL,
    completed_at timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_testrun_case ON testnet_test_run (test_case_id);

DROP TABLE IF EXISTS testnet_asset_vul CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_vul (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    asset_type varchar(64) DEFAULT NULL,
    asset_id varchar(64) DEFAULT NULL,
    vul_name varchar(1024) DEFAULT NULL,
    dedupe_hash varchar(64) DEFAULT NULL,
    request_body text,
    response_body text,
    vul_type varchar(128) DEFAULT NULL,
    source varchar(128) DEFAULT NULL,
    vul_status varchar(64) DEFAULT NULL,
    severity varchar(64) DEFAULT NULL,
    vul_desc text,
    vul_url varchar(1024) DEFAULT NULL,
    payload text,
    project_id varchar(64) DEFAULT NULL,
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    owner varchar(999) DEFAULT NULL,
    fix_suggestion text,
    screen_shoot varchar(255) DEFAULT NULL,
    comment text,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    custom_fields jsonb DEFAULT NULL,
    version int DEFAULT 1,
    ip_id varchar(64) DEFAULT NULL,
    domain_id varchar(64) DEFAULT NULL,
    subdomain_id varchar(64) DEFAULT NULL,
    port_id varchar(64) DEFAULT NULL,
    web_id varchar(64) DEFAULT NULL,
    found_time timestamp DEFAULT NULL,
    fix_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_vul_dedupe_hash ON testnet_asset_vul (dedupe_hash);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_status ON testnet_asset_vul (vul_status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_asset ON testnet_asset_vul (asset_type, asset_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_asset_id ON testnet_asset_vul (asset_id);
CREATE INDEX IF NOT EXISTS fk_project_id_vul ON testnet_asset_vul (project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_lifecycle_status ON testnet_asset_vul (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_last_verified ON testnet_asset_vul (last_verified);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_severity ON testnet_asset_vul (severity);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_ip ON testnet_asset_vul (ip_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_domain ON testnet_asset_vul (domain_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_subdomain ON testnet_asset_vul (subdomain_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_port ON testnet_asset_vul (port_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_vul_web ON testnet_asset_vul (web_id);

DROP TABLE IF EXISTS testnet_asset_web CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_web (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    web_title varchar(1024) DEFAULT NULL,
    favicon varchar(128) DEFAULT NULL,
    port_id varchar(64) DEFAULT NULL,
    screenshot varchar(255) DEFAULT NULL,
    source varchar(255) DEFAULT NULL,
    web_header text,
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    screenshot_file_id varchar(64) DEFAULT NULL,
    favicon_file_id varchar(64) DEFAULT NULL,
    tech varchar(2000) DEFAULT NULL,
    status_code int DEFAULT NULL,
    method varchar(64) DEFAULT NULL,
    web_server varchar(256) DEFAULT NULL,
    web_url varchar(256) DEFAULT NULL,
    content_type varchar(256) DEFAULT NULL,
    content_length int DEFAULT NULL,
    delay_time varchar(64) DEFAULT NULL,
    http_schema varchar(64) DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    jarm varchar(128) DEFAULT NULL,
    body_md5 varchar(128) DEFAULT NULL,
    header_md5 varchar(128) DEFAULT NULL,
    subdomain_id varchar(64) DEFAULT NULL,
    icon_url varchar(256) DEFAULT NULL,
    comment varchar(1024) DEFAULT NULL,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    custom_fields jsonb DEFAULT NULL,
    version int DEFAULT 1,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_web_url_project_id ON testnet_asset_web (web_url, project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_web_subdomain ON testnet_asset_web (subdomain_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_web_port_id ON testnet_asset_web (port_id);
CREATE INDEX IF NOT EXISTS fk_project_id_web ON testnet_asset_web (project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_web_status ON testnet_asset_web (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_web_last_verified ON testnet_asset_web (last_verified);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_web_screenshot_file ON testnet_asset_web (screenshot_file_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_web_favicon_file ON testnet_asset_web (favicon_file_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_web_web_server ON testnet_asset_web (web_server);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_web_status_code ON testnet_asset_web (status_code);

DROP TABLE IF EXISTS testnet_asset_api_tree CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_api_tree (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    label varchar(255) DEFAULT NULL,
    asset_web_id varchar(64) DEFAULT NULL,
    pid varchar(64) DEFAULT NULL,
    relative_path varchar(255) DEFAULT NULL,
    absolute_path varchar(512) DEFAULT NULL,
    full_path_hash varchar(64) DEFAULT NULL,
    type varchar(64) DEFAULT NULL,
    source varchar(64) DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    version int DEFAULT 1,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_api_tree_node ON testnet_asset_api_tree (asset_web_id, full_path_hash);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_api_tree_pid ON testnet_asset_api_tree (pid);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_api_tree_relative_path ON testnet_asset_api_tree (relative_path);
CREATE INDEX IF NOT EXISTS fk_project_id_api_tree ON testnet_asset_api_tree (project_id);
CREATE INDEX IF NOT EXISTS fk_api_tree_to_web ON testnet_asset_api_tree (asset_web_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_api_tree_status ON testnet_asset_api_tree (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_api_tree_last_verified ON testnet_asset_api_tree (last_verified);

DROP TABLE IF EXISTS testnet_asset_api CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_api (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    asset_web_tree_id varchar(64) DEFAULT NULL,
    web_id varchar(64) DEFAULT NULL,
    parent_id varchar(64) DEFAULT NULL,
    api_path varchar(255) DEFAULT NULL,
    http_method varchar(64) DEFAULT NULL,
    request_header text,
    request_params jsonb DEFAULT NULL,
    request_body text,
    response_header text,
    response_body text,
    source varchar(64) DEFAULT NULL,
    hash varchar(256) DEFAULT NULL,
    project_id varchar(64) DEFAULT NULL,
    status_code int DEFAULT NULL,
    path_md5 varchar(64) DEFAULT NULL,
    title varchar(1000) DEFAULT NULL,
    content_type varchar(64) DEFAULT NULL,
    content_length int DEFAULT NULL,
    asset_label varchar(1000) DEFAULT NULL,
    asset_manager varchar(1000) DEFAULT NULL,
    asset_department varchar(1000) DEFAULT NULL,
    comment varchar(1024) DEFAULT NULL,
    last_verified timestamp DEFAULT NULL,
    status varchar(64) DEFAULT 'ACTIVE',
    custom_fields jsonb DEFAULT NULL,
    version int DEFAULT 1,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_asset_api_api ON testnet_asset_api (hash);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_api_tree_id ON testnet_asset_api (asset_web_tree_id);
CREATE INDEX IF NOT EXISTS fk_project_id_api ON testnet_asset_api (project_id);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_api_status ON testnet_asset_api (status);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_api_last_verified ON testnet_asset_api (last_verified);

-- =======================================================
-- Workflow & Other Business Tables
-- =======================================================

DROP TABLE IF EXISTS testnet_client CASCADE;

CREATE TABLE IF NOT EXISTS testnet_client (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    client_name varchar(255) DEFAULT NULL,
    client_version varchar(255) DEFAULT NULL,
    status varchar(64) DEFAULT NULL,
    cpu_usage smallint DEFAULT NULL,
    cpu_cores int DEFAULT NULL,
    total_memory int DEFAULT NULL,
    free_memory int DEFAULT NULL,
    os_platform varchar(255) DEFAULT NULL,
    os_arch varchar(255) DEFAULT NULL,
    hostname varchar(255) DEFAULT NULL,
    ip_address varchar(255) DEFAULT NULL,
    mac_address varchar(255) DEFAULT NULL,
    disk_total bigint DEFAULT NULL,
    disk_free bigint DEFAULT NULL,
    uptime bigint DEFAULT NULL,
    client_config text DEFAULT NULL,
    config_version int DEFAULT 0,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_testnet_client_client_name ON testnet_client (client_name);

DROP TABLE IF EXISTS testnet_client_tool_version CASCADE;

CREATE TABLE IF NOT EXISTS testnet_client_tool_version (
    id varchar(64) NOT NULL,
    tool_id varchar(64) NOT NULL,
    version int NOT NULL,
    configuration text,
    changed_by varchar(64) DEFAULT NULL,
    changed_at timestamp DEFAULT NULL,
    change_note varchar(500) DEFAULT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
);

DROP TABLE IF EXISTS testnet_config_file CASCADE;

CREATE TABLE IF NOT EXISTS testnet_config_file (
    id varchar(64) NOT NULL,
    name varchar(128) NOT NULL,
    description varchar(512) DEFAULT NULL,
    file_type varchar(64) NOT NULL,
    original_filename varchar(255) NOT NULL,
    storage_path varchar(512) NOT NULL,
    file_size bigint NOT NULL,
    content_hash varchar(64) NOT NULL,
    mime_type varchar(128) DEFAULT NULL,
    is_archive smallint DEFAULT 0,
    variables jsonb DEFAULT NULL,
    tags varchar(512) DEFAULT NULL,
    status varchar(20) DEFAULT 'ACTIVE',
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT CURRENT_TIMESTAMP,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_config_file_status ON testnet_config_file (status);
CREATE INDEX IF NOT EXISTS idx_config_file_hash ON testnet_config_file (content_hash);
CREATE INDEX IF NOT EXISTS idx_config_file_create_by ON testnet_config_file (create_by);

DROP TABLE IF EXISTS testnet_domain_event CASCADE;

CREATE TABLE IF NOT EXISTS testnet_domain_event (
    id varchar(64) NOT NULL,
    event_id varchar(64) NOT NULL,
    event_type varchar(64) NOT NULL,
    aggregate_type varchar(64) NOT NULL,
    aggregate_id varchar(64) NOT NULL,
    payload jsonb DEFAULT NULL,
    metadata jsonb DEFAULT NULL,
    status varchar(20) DEFAULT 'PENDING',
    retry_count int DEFAULT 0,
    max_retries int DEFAULT 3,
    next_retry_at timestamp DEFAULT NULL,
    error_message text,
    processed_at timestamp DEFAULT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_event_id ON testnet_domain_event (event_id);
CREATE INDEX IF NOT EXISTS idx_testnet_domain_event_status_retry ON testnet_domain_event (status, next_retry_at);
CREATE INDEX IF NOT EXISTS idx_testnet_domain_event_aggregate ON testnet_domain_event (aggregate_type, aggregate_id);
CREATE INDEX IF NOT EXISTS idx_testnet_domain_event_event_type ON testnet_domain_event (event_type);

DROP TABLE IF EXISTS testnet_file_storage CASCADE;

CREATE TABLE IF NOT EXISTS testnet_file_storage (
    id varchar(64) NOT NULL,
    file_name varchar(255) NOT NULL,
    file_key varchar(512) NOT NULL,
    file_size bigint NOT NULL,
    content_type varchar(100) DEFAULT NULL,
    storage_type varchar(20) NOT NULL DEFAULT 'LOCAL',
    file_hash varchar(64) DEFAULT NULL,
    related_type varchar(64) DEFAULT NULL,
    related_id varchar(64) DEFAULT NULL,
    uploader varchar(64) DEFAULT NULL,
    create_by varchar(64) DEFAULT NULL,
    expire_time timestamp DEFAULT NULL,
    is_deleted smallint DEFAULT 0,
    remark varchar(500) DEFAULT NULL,
    create_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_testnet_file_storage_related ON testnet_file_storage (related_type, related_id);
CREATE INDEX IF NOT EXISTS idx_testnet_file_storage_expire ON testnet_file_storage (expire_time);
CREATE INDEX IF NOT EXISTS idx_testnet_file_storage_hash ON testnet_file_storage (file_hash);
CREATE INDEX IF NOT EXISTS idx_testnet_file_storage_uploader ON testnet_file_storage (uploader);
CREATE INDEX IF NOT EXISTS idx_testnet_file_storage_create_time ON testnet_file_storage (create_time);

DROP TABLE IF EXISTS testnet_install_flag CASCADE;

CREATE TABLE IF NOT EXISTS testnet_install_flag (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    installed int DEFAULT NULL,
    PRIMARY KEY (id)
);

DROP TABLE IF EXISTS testnet_notification CASCADE;

CREATE TABLE IF NOT EXISTS testnet_notification (
    id varchar(64) NOT NULL,
    user_id varchar(64) NOT NULL,
    event_type varchar(64) NOT NULL,
    title varchar(255) NOT NULL,
    content text NOT NULL,
    extra_data jsonb DEFAULT NULL,
    read_status smallint DEFAULT 0,
    severity VARCHAR(20) DEFAULT 'info',
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT CURRENT_TIMESTAMP,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_testnet_notification_user_read ON testnet_notification (user_id, read_status);
CREATE INDEX IF NOT EXISTS idx_testnet_notification_create_time ON testnet_notification (create_time);

-- --------------------------------------------------------
-- 工具规格表 (替代 testnet_client_tool 的契约部分)
-- --------------------------------------------------------
DROP TABLE IF EXISTS testnet_tool_spec CASCADE;

CREATE TABLE IF NOT EXISTS testnet_tool_spec (
    id VARCHAR(64) NOT NULL,
    script_key VARCHAR(100) NOT NULL,
    configuration TEXT DEFAULT NULL,
    source_url VARCHAR(500) DEFAULT NULL,
    checksum VARCHAR(128) DEFAULT NULL,
    version VARCHAR(64) DEFAULT NULL,
    type VARCHAR(64) DEFAULT NULL,
    category VARCHAR(64) DEFAULT NULL,
    supported_asset_types VARCHAR(255) DEFAULT NULL,
    registry_id VARCHAR(64) DEFAULT NULL,
    name VARCHAR(255) DEFAULT NULL,
    status VARCHAR(64) DEFAULT 'ENABLE',
    is_local boolean DEFAULT true,
    create_by VARCHAR(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by VARCHAR(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_tool_spec_script_key ON testnet_tool_spec (script_key);
CREATE INDEX IF NOT EXISTS idx_tool_spec_category ON testnet_tool_spec (category);
CREATE INDEX IF NOT EXISTS idx_tool_spec_supported_asset_types ON testnet_tool_spec (supported_asset_types);
CREATE INDEX IF NOT EXISTS idx_tool_spec_status ON testnet_tool_spec (status);
CREATE INDEX IF NOT EXISTS idx_tool_spec_is_local ON testnet_tool_spec (is_local);
CREATE INDEX IF NOT EXISTS idx_tool_spec_registry_id ON testnet_tool_spec (registry_id);
CREATE INDEX IF NOT EXISTS idx_tool_spec_name ON testnet_tool_spec (name);

-- --------------------------------------------------------
-- 工作流规格表 (替代 testnet_scan_workflow)
-- --------------------------------------------------------
DROP TABLE IF EXISTS testnet_workflow_spec CASCADE;

CREATE TABLE IF NOT EXISTS testnet_workflow_spec (
    id VARCHAR(64) NOT NULL,
    script_key VARCHAR(100) NOT NULL,
    configuration TEXT DEFAULT NULL,
    source_url VARCHAR(500) DEFAULT NULL,
    checksum VARCHAR(128) DEFAULT NULL,
    version VARCHAR(64) DEFAULT NULL,
    registry_id VARCHAR(64) DEFAULT NULL,
    trigger_mode VARCHAR(64) DEFAULT NULL,
    cron_expression VARCHAR(255) DEFAULT NULL,
    status VARCHAR(64) DEFAULT 'ENABLE',
    enabled boolean DEFAULT true,
    is_template boolean DEFAULT false,
    is_local boolean DEFAULT true,
    next_run_time timestamp DEFAULT NULL,
    last_run_time timestamp DEFAULT NULL,
    create_by VARCHAR(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by VARCHAR(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_workflow_spec_script_key ON testnet_workflow_spec (script_key);
CREATE INDEX IF NOT EXISTS idx_workflow_spec_trigger_mode ON testnet_workflow_spec (trigger_mode);
CREATE INDEX IF NOT EXISTS idx_workflow_spec_status ON testnet_workflow_spec (status);
CREATE INDEX IF NOT EXISTS idx_workflow_spec_enabled_next_run ON testnet_workflow_spec (enabled, next_run_time);
CREATE INDEX IF NOT EXISTS idx_workflow_spec_is_local ON testnet_workflow_spec (is_local);
CREATE INDEX IF NOT EXISTS idx_workflow_spec_registry_id ON testnet_workflow_spec (registry_id);

-- --------------------------------------------------------
-- 已安装包追踪表
-- --------------------------------------------------------
DROP TABLE IF EXISTS testnet_installed_package CASCADE;

CREATE TABLE IF NOT EXISTS testnet_installed_package (
    id VARCHAR(64) NOT NULL,
    package_type VARCHAR(20) NOT NULL,
    package_id VARCHAR(100) NOT NULL,
    local_spec_id VARCHAR(64) NOT NULL,
    registry_id VARCHAR(64) DEFAULT NULL,
    remote_version VARCHAR(64) NOT NULL,
    installed_at timestamp NOT NULL,
    checksum VARCHAR(128) DEFAULT NULL,
    update_available smallint DEFAULT 0,
    latest_version VARCHAR(64) DEFAULT NULL,
    create_by VARCHAR(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by VARCHAR(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS idx_installed_package_unique ON testnet_installed_package (package_type, package_id);
CREATE INDEX IF NOT EXISTS idx_installed_package_type ON testnet_installed_package (package_type);
CREATE INDEX IF NOT EXISTS idx_installed_package_registry_id ON testnet_installed_package (registry_id);
CREATE INDEX IF NOT EXISTS idx_installed_package_update ON testnet_installed_package (update_available);

-- --------------------------------------------------------
-- 工作流运行表 (替代隐含在 asset_task 中的运行追踪)
-- --------------------------------------------------------
DROP TABLE IF EXISTS testnet_workflow_run CASCADE;

CREATE TABLE IF NOT EXISTS testnet_workflow_run (
    id VARCHAR(64) NOT NULL,
    workflow_id VARCHAR(64) NOT NULL,
    project_id VARCHAR(64) DEFAULT NULL,
    status VARCHAR(64) DEFAULT 'RUNNING',
    trigger_mode VARCHAR(64) DEFAULT NULL,
    triggered_by VARCHAR(64) DEFAULT NULL,
    total_tasks INT DEFAULT 0,
    completed_tasks INT DEFAULT 0,
    failed_tasks INT DEFAULT 0,
    skipped_tasks INT DEFAULT 0,
    cancelled_tasks INT DEFAULT 0,
    error_strategy VARCHAR(64) DEFAULT 'STOP',
    error_message TEXT DEFAULT NULL,
    trace_id VARCHAR(100) DEFAULT NULL,
    metadata jsonb DEFAULT NULL,
    workflow_spec_snapshot jsonb DEFAULT NULL,
    tool_specs_snapshot jsonb DEFAULT NULL,
    started_at timestamp DEFAULT NULL,
    finished_at timestamp DEFAULT NULL,
    create_by VARCHAR(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by VARCHAR(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    is_deleted smallint DEFAULT 0,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_workflow_run_workflow_id ON testnet_workflow_run (workflow_id);
CREATE INDEX IF NOT EXISTS idx_workflow_run_status ON testnet_workflow_run (status);
CREATE INDEX IF NOT EXISTS idx_workflow_run_project_id ON testnet_workflow_run (project_id);

DROP TABLE IF EXISTS testnet_workflow_node_run CASCADE;

CREATE TABLE IF NOT EXISTS testnet_workflow_node_run (
    id VARCHAR(64) NOT NULL,
    run_id VARCHAR(64) NOT NULL,
    workflow_id VARCHAR(64) NOT NULL,
    node_id VARCHAR(100) NOT NULL,
    tool_ref VARCHAR(128) DEFAULT NULL,
    status VARCHAR(32) DEFAULT 'PENDING',
    total_tasks INT DEFAULT 0,
    completed_tasks INT DEFAULT 0,
    failed_tasks INT DEFAULT 0,
    skipped_tasks INT DEFAULT 0,
    cancelled_tasks INT DEFAULT 0,
    depends_on_policy VARCHAR(32) DEFAULT NULL,
    when_expression TEXT DEFAULT NULL,
    error_message TEXT DEFAULT NULL,
    input_bindings jsonb DEFAULT NULL,
    output_channels jsonb DEFAULT NULL,
    metadata jsonb DEFAULT NULL,
    started_at timestamp DEFAULT NULL,
    finished_at timestamp DEFAULT NULL,
    create_by VARCHAR(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by VARCHAR(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    is_deleted smallint DEFAULT 0,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_node_run ON testnet_workflow_node_run (run_id, node_id);
CREATE INDEX IF NOT EXISTS idx_node_run_run_id ON testnet_workflow_node_run (run_id);
CREATE INDEX IF NOT EXISTS idx_node_run_status ON testnet_workflow_node_run (run_id, status);
CREATE INDEX IF NOT EXISTS idx_node_run_workflow_id ON testnet_workflow_node_run (workflow_id);

-- --------------------------------------------------------
-- 资产信封表 (新增 - 多通道资产传递)
-- --------------------------------------------------------
DROP TABLE IF EXISTS testnet_asset_envelope CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_envelope (
    id VARCHAR(64) NOT NULL,
    run_id VARCHAR(100) NOT NULL,
    source_node_id VARCHAR(100) NOT NULL,
    output_channel VARCHAR(100) NOT NULL,
    asset_id VARCHAR(64) NOT NULL,
    asset_type VARCHAR(64) NOT NULL,
    payload jsonb DEFAULT NULL,
    trace_id VARCHAR(100) DEFAULT NULL,
    parent_asset_id VARCHAR(64) DEFAULT NULL,
    parent_asset_ids jsonb DEFAULT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_asset_envelope_run_node ON testnet_asset_envelope (run_id, source_node_id);
CREATE INDEX IF NOT EXISTS idx_asset_envelope_channel ON testnet_asset_envelope (run_id, output_channel);
CREATE INDEX IF NOT EXISTS idx_asset_envelope_asset ON testnet_asset_envelope (asset_id, asset_type);

DROP TABLE IF EXISTS testnet_workflow_asset_result CASCADE;

CREATE TABLE IF NOT EXISTS testnet_workflow_asset_result (
    id varchar(64) NOT NULL,
    run_id varchar(100) NOT NULL,
    node_id varchar(100) NOT NULL,
    asset_id varchar(64) NOT NULL,
    asset_type varchar(64) NOT NULL,
    create_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_run_node ON testnet_workflow_asset_result (run_id, node_id);
CREATE INDEX IF NOT EXISTS idx_asset ON testnet_workflow_asset_result (asset_id, asset_type);

DROP TABLE IF EXISTS testnet_asset_trace CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_trace (
    id varchar(64) NOT NULL,
    run_id varchar(100) NOT NULL,
    node_id varchar(100) NOT NULL,
    asset_id varchar(64) NOT NULL,
    asset_type varchar(64) NOT NULL,
    parent_asset_id varchar(64) DEFAULT NULL,
    source_node_id varchar(100) DEFAULT NULL,
    trace_id varchar(100) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_trace_run ON testnet_asset_trace (run_id, trace_id);
CREATE INDEX IF NOT EXISTS idx_asset_trace ON testnet_asset_trace (asset_id, node_id);

DROP TABLE IF EXISTS testnet_asset_trace_parent CASCADE;

CREATE TABLE IF NOT EXISTS testnet_asset_trace_parent (
    id varchar(64) NOT NULL,
    trace_id varchar(64) NOT NULL,
    parent_asset_id varchar(64) NOT NULL,
    create_time timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_trace_id ON testnet_asset_trace_parent (trace_id);
CREATE INDEX IF NOT EXISTS idx_parent_id ON testnet_asset_trace_parent (parent_asset_id);

DROP TABLE IF EXISTS testnet_search_engine_syntax CASCADE;

CREATE TABLE IF NOT EXISTS testnet_search_engine_syntax (
    id varchar(64) NOT NULL,
    create_by varchar(100) DEFAULT NULL,
    engine varchar(64) NOT NULL,
    syntax varchar(100) NOT NULL,
    description varchar(255) DEFAULT NULL,
    example varchar(255) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    update_by varchar(100) DEFAULT NULL,
    PRIMARY KEY (id)
);

DROP TABLE IF EXISTS testnet_task_execution_log CASCADE;

CREATE TABLE IF NOT EXISTS testnet_task_execution_log (
    id varchar(64) NOT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    task_id varchar(64) NOT NULL,
    client_id varchar(64) DEFAULT NULL,
    log_level varchar(16) DEFAULT 'INFO',
    content text NOT NULL,
    trace_id varchar(128) DEFAULT NULL,
    run_id varchar(200) DEFAULT NULL,
    span_id varchar(64) DEFAULT NULL,
    category varchar(255) DEFAULT NULL,
    metadata jsonb DEFAULT NULL,
    PRIMARY KEY (id)
    );
CREATE INDEX IF NOT EXISTS idx_testnet_task_execution_log_task_execution_log_task ON testnet_task_execution_log (task_id);
CREATE INDEX IF NOT EXISTS idx_testnet_task_execution_log_task_execution_log_create_time ON testnet_task_execution_log (create_time);

DROP TABLE IF EXISTS testnet_tool_config_file CASCADE;

CREATE TABLE IF NOT EXISTS testnet_tool_config_file (
    id varchar(64) NOT NULL,
    tool_id varchar(64) NOT NULL,
    config_file_id varchar(64) NOT NULL,
    usage_type varchar(64) NOT NULL,
    target_path varchar(512) DEFAULT NULL,
    template_string varchar(1024) DEFAULT NULL,
    container_path varchar(512) DEFAULT NULL,
    read_only smallint DEFAULT 1,
    required smallint DEFAULT 1,
    variable_values jsonb DEFAULT NULL,
    create_by varchar(64) DEFAULT NULL,
    create_time timestamp DEFAULT CURRENT_TIMESTAMP,
    update_by varchar(64) DEFAULT NULL,
    update_time timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_tool_config ON testnet_tool_config_file (tool_id, config_file_id);
CREATE INDEX IF NOT EXISTS idx_tool_config_tool ON testnet_tool_config_file (tool_id);
CREATE INDEX IF NOT EXISTS idx_tool_config_file ON testnet_tool_config_file (config_file_id);

DROP TABLE IF EXISTS testnet_tool_execution_stats CASCADE;

CREATE TABLE IF NOT EXISTS testnet_tool_execution_stats (
    id varchar(64) NOT NULL,
    tool_id varchar(64) NOT NULL,
    total_executions int DEFAULT 0,
    success_count int DEFAULT 0,
    failure_count int DEFAULT 0,
    total_duration_ms bigint DEFAULT 0,
    avg_duration_ms bigint DEFAULT 0,
    min_duration_ms bigint DEFAULT NULL,
    max_duration_ms bigint DEFAULT NULL,
    avg_output_size bigint DEFAULT 0,
    last_executed_at timestamp DEFAULT NULL,
    last_success_at timestamp DEFAULT NULL,
    last_failure_at timestamp DEFAULT NULL,
    last_error_message varchar(1000) DEFAULT NULL,
    create_time timestamp DEFAULT NULL,
    update_time timestamp DEFAULT NULL,
    version int DEFAULT 0,
    PRIMARY KEY (id)
    );
CREATE UNIQUE INDEX IF NOT EXISTS uk_tool_id ON testnet_tool_execution_stats (tool_id);

INSERT INTO
    testnet_asset_search_engine (
        id,
        create_by,
        create_time,
        update_by,
        update_time,
        sys_org_code,
        engine_name,
        engine_type,
        engine_token,
        engine_host,
        status,
        sort_order,
        default_page_size
    )
VALUES (
        '1808335866473504769',
        'admin',
        NOW(),
        NULL,
        NOW(),
        'A01',
        'shodan',
        'shodan',
        'xxxx',
        'https://api.shodan.io/shodan/host/search',
        'ACTIVE',
        60,
        100
    ),
    (
        '1808336360352800769',
        'admin',
        NOW(),
        NULL,
        NOW(),
        'A01',
        'quake',
        'quake',
        'xxxx',
        'https://quake.360.net/api/v3/search/quake_service',
        'ACTIVE',
        30,
        100
    ),
    (
        '1808336376505065473',
        'admin',
        NOW(),
        NULL,
        NOW(),
        'A01',
        'fofa',
        'fofa',
        'xxxx',
        'https://fofa.info',
        'ACTIVE',
        10,
        100
    ),
    (
        '1808336391080271873',
        'admin',
        NOW(),
        NULL,
        NOW(),
        'A01',
        'hunter',
        'hunter',
        'xxxx',
        'https://hunter.qianxin.com/openApi/search',
        'ACTIVE',
        20,
        100
    ),
    (
        '1808336391080271874',
        'admin',
        NOW(),
        NULL,
        NOW(),
        'A01',
        'zoomeye',
        'zoomeye',
        'xxxx',
        'https://api.zoomeye.org/v2/search',
        'ACTIVE',
        50,
        100
    ),
    (
        '1808312391080271873',
        'admin',
        NOW(),
        NULL,
        NOW(),
        'A01',
        '0zone',
        '0zone',
        'xxxx',
        'https://0.zone/api/data/',
        'ACTIVE',
        40,
        100
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    sys_department
VALUES (
        '1',
        '0',
        '总公司',
        'HQ',
        1,
        NULL,
        NULL,
        NULL,
        'ACTIVE',
        NULL,
        NOW(),
        NULL,
        NULL,
        NULL
    ),
    (
        '2',
        '0',
        '技术部',
        'TECH',
        1,
        NULL,
        NULL,
        NULL,
        'ACTIVE',
        NULL,
        NOW(),
        NULL,
        NULL,
        NULL
    ),
    (
        '3',
        '0',
        '安全部',
        'SEC',
        2,
        NULL,
        NULL,
        NULL,
        'ACTIVE',
        NULL,
        NOW(),
        NULL,
        NULL,
        NULL
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    sys_role
VALUES (
        '1',
        'SUPER_ADMIN',
        '超级管理员',
        '拥有所有权限',
        1,
        'ACTIVE',
        NULL,
        NOW(),
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        '2',
        'ADMIN',
        '管理员',
        '拥有大部分管理权限',
        2,
        'ACTIVE',
        NULL,
        NOW(),
        NULL,
        NULL,
        NULL,
        NULL
    ),
    (
        '3',
        'USER',
        '普通用户',
        '普通用户权限',
        3,
        'ACTIVE',
        NULL,
        NOW(),
        NULL,
        NULL,
        NULL,
        NULL
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    sys_user
VALUES (
        '1',
        'admin',
        '$2a$10$gBwo3rcdfVXMS12EQBc0RuDMKR1Om.Nz6bw88cZUDqCGBmA1MVtI6',
        '系统管理员',
        'admin@testnet.com',
        NULL,
        NULL,
        NULL,
        NULL,
        'ACTIVE',
        NULL,
        NULL,
        NULL,
        NOW(),
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    sys_user_role
VALUES (
        '1',
        '1',
        '1',
        NULL,
        NOW(),
        NULL,
        NULL
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_search_engine_syntax
VALUES (
        'fofa_01',
        NULL,
        'fofa',
        'title=',
        '搜索页面标题',
        '"wordpress"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_02',
        NULL,
        'fofa',
        'body=',
        '搜索页面内容',
        '"loading-wrap"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_03',
        NULL,
        'fofa',
        'domain=',
        '搜索对应域名',
        '"example.com"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_04',
        NULL,
        'fofa',
        'port=',
        '搜索特定端口',
        '"80"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_05',
        NULL,
        'fofa',
        'protocol=',
        '搜索特定协议',
        '"https"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_06',
        NULL,
        'fofa',
        'country=',
        '搜索国家代码',
        '"CN"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_07',
        NULL,
        'fofa',
        'cert=',
        '搜索证书',
        '"google"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_08',
        NULL,
        'fofa',
        'icon_hash=',
        '搜索图标 Hash',
        '"-247580611"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_09',
        NULL,
        'fofa',
        '&&',
        '逻辑与 (AND)',
        'title="abc" && body="123"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'fofa_10',
        NULL,
        'fofa',
        '||',
        '逻辑或 (OR)',
        'title="abc" || body="123"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'shodan_01',
        NULL,
        'shodan',
        'product:',
        '搜索产品名称',
        '"Apache"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'shodan_02',
        NULL,
        'shodan',
        'port:',
        '搜索特定端口',
        80,
        NOW(),
        NULL,
        NULL
    ),
    (
        'shodan_03',
        NULL,
        'shodan',
        'country:',
        '搜索国家代码',
        '"US"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'shodan_04',
        NULL,
        'shodan',
        'os:',
        '搜索操作系统',
        '"Windows"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'shodan_05',
        NULL,
        'shodan',
        'net:',
        '搜索 IP 段',
        '"192.168.1.0/24"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'shodan_06',
        NULL,
        'shodan',
        'hostname:',
        '搜索主机名',
        '"google.com"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'shodan_07',
        NULL,
        'shodan',
        'title:',
        '搜索网页标题',
        '"Index of /"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'shodan_08',
        NULL,
        'shodan',
        'vuln:',
        '搜索 CVE 漏洞',
        '"CVE-2014-0160"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_01',
        NULL,
        'hunter',
        'ip=',
        '搜索单个 IP/段',
        '"1.1.1.1"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_02',
        NULL,
        'hunter',
        'domain=',
        '搜索特定域名',
        '"example.com"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_03',
        NULL,
        'hunter',
        'web.title=',
        '搜索网页标题',
        '"Index of /"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_04',
        NULL,
        'hunter',
        'port=',
        '搜索特定端口',
        80,
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_05',
        NULL,
        'hunter',
        'protocol=',
        '搜索特定协议',
        '"http"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_06',
        NULL,
        'hunter',
        'ip.city=',
        '搜索城市',
        '"Beijing"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_07',
        NULL,
        'hunter',
        'header=',
        '搜索 HTTP 头',
        '"nginx"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_08',
        NULL,
        'hunter',
        'cert.subject=',
        '搜索证书主题',
        '"google.com"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'hunter_09',
        NULL,
        'hunter',
        '!==',
        '不等于 (精确)',
        'ip!=="1.1.1.1"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'quake_01',
        NULL,
        'quake',
        'ip:',
        '搜索 IP',
        '"1.1.1.1"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'quake_02',
        NULL,
        'quake',
        'port:',
        '搜索端口',
        80,
        NOW(),
        NULL,
        NULL
    ),
    (
        'quake_03',
        NULL,
        'quake',
        'domain:',
        '搜索域名',
        '"example.com"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'quake_04',
        NULL,
        'quake',
        'title:',
        '搜索网页标题',
        '"admin"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'quake_05',
        NULL,
        'quake',
        'app:',
        '搜索应用',
        '"nginx"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'quake_06',
        NULL,
        'quake',
        'country:',
        '搜索国家代码',
        '"CN"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'quake_07',
        NULL,
        'quake',
        'AND',
        '逻辑与',
        'ip:"1.1.1.1" AND port:80',
        NOW(),
        NULL,
        NULL
    ),
    (
        'quake_08',
        NULL,
        'quake',
        'OR',
        '逻辑或',
        'ip:"1.1.1.1" OR ip:"2.2.2.2"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'zoomeye_01',
        NULL,
        'zoomeye',
        'app:',
        '搜索应用名',
        '"Apache"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'zoomeye_02',
        NULL,
        'zoomeye',
        'ver:',
        '搜索版本号',
        '"2.4.7"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'zoomeye_03',
        NULL,
        'zoomeye',
        'ip:',
        '搜索 IP',
        '"1.1.1.1"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'zoomeye_04',
        NULL,
        'zoomeye',
        'site:',
        '搜索站点',
        '"google.com"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'zoomeye_05',
        NULL,
        'zoomeye',
        'title:',
        '搜索网页标题',
        '"index of /"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'zoomeye_06',
        NULL,
        'zoomeye',
        'port:',
        '搜索端口',
        80,
        NOW(),
        NULL,
        NULL
    ),
    (
        'zoomeye_07',
        NULL,
        'zoomeye',
        '==',
        '精确匹配',
        'app:=="Apache"',
        NOW(),
        NULL,
        NULL
    ),
    (
        'zoomeye_08',
        NULL,
        'zoomeye',
        '&&',
        '逻辑与',
        'app:"Apache" && port:80',
        NOW(),
        NULL,
        NULL
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_install_flag
VALUES (
        '1866098861832536065',
        'admin',
        NOW(),
        NULL,
        NOW(),
        0
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        status,
        extra_config,
        sort_order,
        create_time
    )
VALUES (
        'history_cleanup_default',
        'HISTORY_CLEANUP',
        '历史记录清理配置',
        'ACTIVE',
        '{"retentionDays":90,"enabled":true,"cleanupHour":3}',
        1,
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    extra_config = EXCLUDED.extra_config,
    update_time = NOW();

-- =======================================================
-- 默认自动打标规则
-- =======================================================

-- =======================================================
-- 标签字典（必须先于打标规则创建）
-- =======================================================

INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        color,
        sort_order,
        status,
        notes,
        create_by,
        create_time
    )
VALUES (
        'tag-dev-domain',
        'TAG',
        '研发域名',
        'ALL',
        '#8b5cf6',
        4,
        'ACTIVE',
        '研发测试域名',
        'admin',
        NOW()
    ),
    (
        'tag-prod-domain',
        'TAG',
        '生产主域',
        'ALL',
        '#ec4899',
        5,
        'ACTIVE',
        '生产线上主域',
        'admin',
        NOW()
    ),
    (
        'tag-partner',
        'TAG',
        '合作伙伴',
        'ALL',
        '#10b981',
        6,
        'ACTIVE',
        '合作伙伴资产',
        'admin',
        NOW()
    ),
    (
        'tag-shadow',
        'TAG',
        '影子资产',
        'ALL',
        '#6b7280',
        7,
        'ACTIVE',
        '未梳理边缘影子资产',
        'admin',
        NOW()
    ),
    (
        'tag-idc',
        'TAG',
        'IDC',
        'ALL',
        '#14b8a6',
        8,
        'ACTIVE',
        '自建或托管IDC资产',
        'admin',
        NOW()
    ),
    (
        'tag-infrastructure',
        'TAG',
        'Infrastructure',
        'ALL',
        '#f97316',
        9,
        'ACTIVE',
        '底层核心基础架构',
        'admin',
        NOW()
    ),
    (
        'tag-env-test',
        'TAG',
        '测试环境',
        'ALL',
        '#f59e0b',
        1,
        'ACTIVE',
        '测试环境资产标识',
        'admin',
        NOW()
    ),
    (
        'tag-env-prod',
        'TAG',
        '生产环境',
        'ALL',
        '#ef4444',
        2,
        'ACTIVE',
        '生产环境资产标识',
        'admin',
        NOW()
    ),
    (
        'tag-env-dev',
        'TAG',
        '开发环境',
        'ALL',
        '#3b82f6',
        3,
        'ACTIVE',
        '开发环境资产标识',
        'admin',
        NOW()
    ),
    (
        'tag-api',
        'TAG',
        'API接口',
        'SUBDOMAIN',
        '#8b5cf6',
        10,
        'ACTIVE',
        'API接口资产标识',
        'admin',
        NOW()
    ),
    (
        'tag-mobile',
        'TAG',
        '移动端',
        'SUBDOMAIN',
        '#06b6d4',
        11,
        'ACTIVE',
        '移动端接口资产标识',
        'admin',
        NOW()
    ),
    (
        'tag-admin',
        'TAG',
        '后台管理',
        'SUBDOMAIN',
        '#6366f1',
        12,
        'ACTIVE',
        '后台管理系统资产标识',
        'admin',
        NOW()
    ),
    (
        'tag-https',
        'TAG',
        'HTTPS',
        'WEB',
        '#10b981',
        20,
        'ACTIVE',
        'HTTPS网站标识',
        'admin',
        NOW()
    ),
    (
        'tag-mysql',
        'TAG',
        'MySQL数据库',
        'PORT',
        '#f97316',
        30,
        'ACTIVE',
        'MySQL数据库服务标识',
        'admin',
        NOW()
    ),
    (
        'tag-redis',
        'TAG',
        'Redis',
        'PORT',
        '#dc2626',
        31,
        'ACTIVE',
        'Redis服务标识',
        'admin',
        NOW()
    ),
    (
        'tag-postgres',
        'TAG',
        'PostgreSQL',
        'PORT',
        '#2563eb',
        32,
        'ACTIVE',
        'PostgreSQL数据库服务标识',
        'admin',
        NOW()
    ),
    (
        'tag-mongodb',
        'TAG',
        'MongoDB',
        'PORT',
        '#16a34a',
        33,
        'ACTIVE',
        'MongoDB数据库服务标识',
        'admin',
        NOW()
    ),
    (
        'tag-ssh',
        'TAG',
        'SSH服务',
        'PORT',
        '#64748b',
        40,
        'ACTIVE',
        'SSH服务标识',
        'admin',
        NOW()
    ),
    (
        'tag-rdp',
        'TAG',
        '远程桌面',
        'PORT',
        '#7c3aed',
        41,
        'ACTIVE',
        '远程桌面服务标识',
        'admin',
        NOW()
    ),
    (
        'tag-web',
        'TAG',
        'Web服务',
        'PORT',
        '#0ea5e9',
        42,
        'ACTIVE',
        'Web服务标识',
        'admin',
        NOW()
    ),
    (
        'tag-database',
        'TAG',
        '数据库服务',
        'PORT',
        '#eab308',
        43,
        'ACTIVE',
        '数据库服务标识',
        'admin',
        NOW()
    ),
    (
        'tag-company-hq',
        'TAG',
        '总部',
        'COMPANY',
        '#3b82f6',
        50,
        'ACTIVE',
        '总公司/总部标识',
        'admin',
        NOW()
    ),
    (
        'tag-company-sub',
        'TAG',
        '子公司',
        'COMPANY',
        '#10b981',
        51,
        'ACTIVE',
        '子公司标识',
        'admin',
        NOW()
    ),
    (
        'tag-domain-main',
        'TAG',
        '主域名',
        'DOMAIN',
        '#6366f1',
        60,
        'ACTIVE',
        '主域名标识',
        'admin',
        NOW()
    ),
    (
        'tag-ip-public',
        'TAG',
        '公网IP',
        'IP',
        '#f59e0b',
        70,
        'ACTIVE',
        '公网IP标识',
        'admin',
        NOW()
    ),
    (
        'tag-ip-private',
        'TAG',
        '内网IP',
        'IP',
        '#64748b',
        71,
        'ACTIVE',
        '内网IP标识',
        'admin',
        NOW()
    ),
    (
        'tag-api-rest',
        'TAG',
        'RESTful API',
        'API',
        '#22c55e',
        80,
        'ACTIVE',
        'RESTful API标识',
        'admin',
        NOW()
    ),
    (
        'tag-api-graphql',
        'TAG',
        'GraphQL',
        'API',
        '#ec4899',
        81,
        'ACTIVE',
        'GraphQL API标识',
        'admin',
        NOW()
    ),
    (
        'tag-vul-high',
        'TAG',
        '高危漏洞',
        'VUL',
        '#ef4444',
        90,
        'ACTIVE',
        '高危漏洞标识',
        'admin',
        NOW()
    ),
    (
        'tag-vul-medium',
        'TAG',
        '中危漏洞',
        'VUL',
        '#f97316',
        91,
        'ACTIVE',
        '中危漏洞标识',
        'admin',
        NOW()
    ),
    (
        'tag-vul-low',
        'TAG',
        '低危漏洞',
        'VUL',
        '#eab308',
        92,
        'ACTIVE',
        '低危漏洞标识',
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 1. 测试环境识别 - dev
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_dev',
        'AUTO_TAG',
        '测试环境识别-dev',
        'ALL',
        'CONTAINS',
        'dev',
        'tag-env-test',
        'ACTIVE',
        1,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 2. 测试环境识别 - test
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_test',
        'AUTO_TAG',
        '测试环境识别-test',
        'ALL',
        'CONTAINS',
        'test',
        'tag-env-test',
        'ACTIVE',
        2,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 3. 测试环境识别 - uat
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_uat',
        'AUTO_TAG',
        '测试环境识别-uat',
        'ALL',
        'CONTAINS',
        'uat',
        'tag-env-test',
        'ACTIVE',
        3,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 4. 测试环境识别 - staging
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_staging',
        'AUTO_TAG',
        '测试环境识别-staging',
        'ALL',
        'CONTAINS',
        'staging',
        'tag-env-test',
        'ACTIVE',
        4,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 5. 生产环境识别 - prod
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_prod',
        'AUTO_TAG',
        '生产环境识别-prod',
        'ALL',
        'CONTAINS',
        'prod',
        'tag-env-prod',
        'ACTIVE',
        5,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 6. 生产环境识别 - live
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_live',
        'AUTO_TAG',
        '生产环境识别-live',
        'ALL',
        'CONTAINS',
        'live',
        'tag-env-prod',
        'ACTIVE',
        6,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 7. 生产环境识别 - release
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_release',
        'AUTO_TAG',
        '生产环境识别-release',
        'ALL',
        'CONTAINS',
        'release',
        'tag-env-prod',
        'ACTIVE',
        7,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 8. API接口识别
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_api',
        'AUTO_TAG',
        'API接口识别',
        'SUBDOMAIN',
        'subDomain',
        'PREFIX',
        'api.',
        'tag-api',
        'ACTIVE',
        8,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 9. 移动端接口识别
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_mobile',
        'AUTO_TAG',
        '移动端接口识别',
        'SUBDOMAIN',
        'subDomain',
        'PREFIX',
        'm.',
        'tag-mobile',
        'ACTIVE',
        9,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 10. 后台管理系统识别
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_admin',
        'AUTO_TAG',
        '后台管理系统识别',
        'SUBDOMAIN',
        'subDomain',
        'REGEX',
        '^(admin|manage|backend|console|manager).',
        'tag-admin',
        'ACTIVE',
        10,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 11. 开发环境识别 - localhost
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_localhost',
        'AUTO_TAG',
        '开发环境识别-localhost',
        'SUBDOMAIN',
        'subDomain',
        'CONTAINS',
        'localhost',
        'tag-env-dev',
        'ACTIVE',
        11,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 12. HTTPS网站识别
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_https',
        'AUTO_TAG',
        'HTTPS网站识别',
        'WEB',
        'url',
        'PREFIX',
        'https://',
        'tag-https',
        'ACTIVE',
        12,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 13. 数据库端口识别 - MySQL
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_mysql',
        'AUTO_TAG',
        'MySQL数据库识别',
        'PORT',
        'port',
        'EXACT',
        '3306',
        'tag-mysql',
        'ACTIVE',
        13,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 14. 数据库端口识别 - Redis
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_redis',
        'AUTO_TAG',
        'Redis数据库识别',
        'PORT',
        'port',
        'EXACT',
        '6379',
        'tag-redis',
        'ACTIVE',
        14,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 15. 数据库端口识别 - PostgreSQL
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_postgres',
        'AUTO_TAG',
        'PostgreSQL数据库识别',
        'PORT',
        'port',
        'EXACT',
        '5432',
        'tag-postgres',
        'ACTIVE',
        15,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 16. 数据库端口识别 - MongoDB
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_mongodb',
        'AUTO_TAG',
        'MongoDB数据库识别',
        'PORT',
        'port',
        'EXACT',
        '27017',
        'tag-mongodb',
        'ACTIVE',
        16,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 17. SSH服务识别
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_ssh',
        'AUTO_TAG',
        'SSH服务识别',
        'PORT',
        'port',
        'EXACT',
        '22',
        'tag-ssh',
        'ACTIVE',
        17,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 18. 远程桌面识别
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_rdp',
        'AUTO_TAG',
        '远程桌面识别',
        'PORT',
        'port',
        'EXACT',
        '3389',
        'tag-rdp',
        'ACTIVE',
        18,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 19. Web服务识别
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_web',
        'AUTO_TAG',
        'Web服务识别',
        'PORT',
        'port',
        'REGEX',
        '^(80|443|8080|8443|8000|8888)$',
        'tag-web',
        'ACTIVE',
        19,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 20. 数据库服务识别（通过服务名称）
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        tags,
        status,
        sort_order,
        create_by,
        create_time
    )
VALUES (
        'auto_tag_database_service',
        'AUTO_TAG',
        '数据库服务识别',
        'PORT',
        'service',
        'REGEX',
        'mysql|mariadb|postgresql|mongodb|redis|oracle|sqlserver',
        'tag-database',
        'ACTIVE',
        20,
        'admin',
        NOW()
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- =======================================================
-- 默认黑名单规则
-- =======================================================

-- 21. 政府网站黑名单
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        effect_type,
        status,
        sort_order,
        create_by,
        create_time,
        notes
    )
VALUES (
        'blacklist_gov',
        'ACCESS_RULE',
        '政府网站黑名单',
        'SUBDOMAIN',
        'domain',
        'SUFFIX',
        '.gov.cn',
        'BLACKLIST',
        'ACTIVE',
        100,
        'admin',
        NOW(),
        '禁止添加政府网站域名'
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- 22. 教育机构黑名单
INSERT INTO
    testnet_asset_config (
        id,
        config_type,
        name,
        target_type,
        config_key,
        matcher_type,
        matcher_value,
        effect_type,
        status,
        sort_order,
        create_by,
        create_time,
        notes
    )
VALUES (
        'blacklist_edu',
        'ACCESS_RULE',
        '教育机构黑名单',
        'SUBDOMAIN',
        'domain',
        'SUFFIX',
        '.edu.cn',
        'BLACKLIST',
        'ACTIVE',
        101,
        'admin',
        NOW(),
        '禁止添加教育机构域名'
    )
ON CONFLICT (id) DO UPDATE SET
    update_time = NOW();

-- ----------------------------
-- =======================================================
-- TestNet RBAC 权限系统完整配置 v2.0
-- =======================================================

-- =======================================================
-- 一、菜单权限初始化 (前端固定菜单对应的权限码)
-- =======================================================

-- 1.1 顶级菜单权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        path,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'menu-000',
        'dashboard',
        '控制台',
        'MENU',
        '/dashboard',
        '',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-020',
        'project',
        '项目管理',
        'MENU',
        '/project',
        '',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-030',
        'asset',
        '资产管理',
        'MENU',
        '/asset',
        '',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-040',
        'asset-config',
        '资产规则',
        'MENU',
        '/asset/config-group',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-050',
        'search',
        '空间测绘',
        'MENU',
        '/search-group',
        '',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-060',
        'workflow',
        '自动化',
        'MENU',
        '/workflow-group',
        '',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-085',
        'notification',
        '消息中心',
        'MENU',
        '/notification',
        '',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-090',
        'system',
        '系统管理',
        'MENU',
        '/system',
        '',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 1.2 资产管理子菜单
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'menu-031',
        'asset:company',
        '公司信息',
        'MENU',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-032',
        'asset:domain',
        '主域名',
        'MENU',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-033',
        'asset:subdomain',
        '子域名',
        'MENU',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-034',
        'asset:ip',
        'IP资产',
        'MENU',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-035',
        'asset:port',
        '端口',
        'MENU',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-036',
        'asset:web',
        'Web资产',
        'MENU',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-037',
        'asset:api',
        'API',
        'MENU',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-038',
        'asset:vul',
        '漏洞',
        'MENU',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 1.2 资产规则子菜单
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'menu-041',
        'asset:config:tag',
        '标签字典',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-042',
        'asset:config:auto-tag',
        '自动打标',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-043',
        'asset:config:ownership',
        '归属映射',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-044',
        'asset:config:root-domain',
        '顶级域名配置',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-045',
        'asset:config:access-rule',
        '黑白名单',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-046',
        'asset:config:notification',
        '通知联动',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-047',
        'asset:config:vul-type',
        '漏洞类型',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-048',
        'asset:config:history-cleanup',
        '历史清理',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-049',
        'asset:config:custom-field',
        '自定义字段',
        'MENU',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 1.5 空间测绘子菜单
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'menu-051',
        'search:query',
        '搜索',
        'MENU',
        'menu-050',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-052',
        'search:engine',
        '测绘配置',
        'MENU',
        'menu-050',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-053',
        'search:syntax',
        '语法配置',
        'MENU',
        'menu-050',
        'INACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 1.6 工作流子菜单
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'menu-061',
        'workflow:config',
        '工作流配置',
        'MENU',
        'menu-060',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-062',
        'workflow:tool',
        '工具库',
        'MENU',
        'menu-060',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-063',
        'workflow:runs',
        '执行记录',
        'MENU',
        'menu-060',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-064',
        'task:list',
        '任务列表',
        'MENU',
        'menu-060',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-065',
        'client:list',
        '节点列表',
        'MENU',
        '',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-066',
        'config-file:list',
        '配置文件',
        'MENU',
        'menu-060',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 1.7 系统管理子菜单
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'menu-091',
        'system:user',
        '用户管理',
        'MENU',
        'menu-090',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-092',
        'system:role',
        '角色管理',
        'MENU',
        'menu-090',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-093',
        'system:dept',
        '部门管理',
        'MENU',
        'menu-090',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-094',
        'system:permission',
        '权限配置',
        'MENU',
        'menu-090',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-095',
        'system:config',
        '系统配置',
        'MENU',
        'menu-090',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'menu-096',
        'system:license',
        '授权管理',
        'MENU',
        'menu-090',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- =======================================================
-- 二、按钮权限初始化 (sys_permission)
-- =======================================================

-- 2.1 系统管理按钮权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '102',
        'system:user:view',
        '查看用户',
        'BUTTON',
        'menu-091',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '103',
        'system:user:edit',
        '编辑用户',
        'BUTTON',
        'menu-091',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '112',
        'system:role:view',
        '查看角色',
        'BUTTON',
        'menu-092',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '113',
        'system:role:edit',
        '编辑角色',
        'BUTTON',
        'menu-092',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '122',
        'system:dept:view',
        '查看部门',
        'BUTTON',
        'menu-093',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '123',
        'system:dept:edit',
        '编辑部门',
        'BUTTON',
        'menu-093',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '142',
        'system:permission:view',
        '查看权限',
        'BUTTON',
        'menu-094',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '143',
        'system:permission:edit',
        '编辑权限',
        'BUTTON',
        'menu-094',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '152',
        'system:config:view',
        '查看配置',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '153',
        'system:config:edit',
        '编辑配置',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.2 资产管理权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '1002',
        'asset:company:view',
        '查看公司',
        'menu-031',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1003',
        'asset:company:edit',
        '编辑公司',
        'menu-031',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1004',
        'asset:company:export',
        '导出公司',
        'menu-031',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1012',
        'asset:domain:view',
        '查看主域名',
        'menu-032',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1013',
        'asset:domain:edit',
        '编辑主域名',
        'menu-032',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1014',
        'asset:domain:export',
        '导出主域名',
        'menu-032',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1022',
        'asset:subdomain:view',
        '查看子域名',
        'menu-033',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1023',
        'asset:subdomain:edit',
        '编辑子域名',
        'menu-033',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1024',
        'asset:subdomain:export',
        '导出子域名',
        'menu-033',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1032',
        'asset:ip:view',
        '查看IP',
        'menu-034',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1033',
        'asset:ip:edit',
        '编辑IP',
        'menu-034',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1034',
        'asset:ip:export',
        '导出IP',
        'menu-034',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1042',
        'asset:port:view',
        '查看端口',
        'menu-035',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1043',
        'asset:port:edit',
        '编辑端口',
        'menu-035',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1044',
        'asset:port:export',
        '导出端口',
        'menu-035',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1052',
        'asset:web:view',
        '查看Web',
        'menu-036',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1053',
        'asset:web:edit',
        '编辑Web',
        'menu-036',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1054',
        'asset:web:export',
        '导出Web',
        'menu-036',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1062',
        'asset:api:view',
        '查看API',
        'menu-037',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1063',
        'asset:api:edit',
        '编辑API',
        'menu-037',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1064',
        'asset:api:export',
        '导出API',
        'menu-037',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '10005',
        'asset:api:import',
        '导入API',
        'menu-037',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1072',
        'asset:vul:view',
        '查看漏洞',
        'menu-038',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1073',
        'asset:vul:edit',
        '编辑漏洞',
        'menu-038',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '1074',
        'asset:vul:export',
        '导出漏洞',
        'menu-038',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '10006',
        'asset:vul:import',
        '导入漏洞',
        'menu-038',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.3 资产规则权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '2000',
        'asset:config:view',
        '查看配置',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2004',
        'asset:config:edit',
        '编辑配置',
        'menu-040',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2002',
        'asset:config:tag:view',
        '查看标签',
        'menu-041',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2003',
        'asset:config:tag:edit',
        '编辑标签',
        'menu-041',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2012',
        'asset:config:auto-tag:view',
        '查看规则',
        'menu-042',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2013',
        'asset:config:auto-tag:edit',
        '编辑规则',
        'menu-042',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2022',
        'asset:config:ownership:view',
        '查看映射',
        'menu-043',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2023',
        'asset:config:ownership:edit',
        '编辑映射',
        'menu-043',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2032',
        'asset:config:root-domain:view',
        '查看配置',
        'menu-044',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2033',
        'asset:config:root-domain:edit',
        '编辑配置',
        'menu-044',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2042',
        'asset:config:access-rule:view',
        '查看规则',
        'menu-045',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2043',
        'asset:config:access-rule:edit',
        '编辑规则',
        'menu-045',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2052',
        'asset:config:notification:view',
        '查看规则',
        'menu-046',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2053',
        'asset:config:notification:edit',
        '编辑规则',
        'menu-046',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2062',
        'asset:config:vul-type:view',
        '查看类型',
        'menu-047',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2063',
        'asset:config:vul-type:edit',
        '编辑类型',
        'menu-047',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2072',
        'asset:config:history-cleanup:view',
        '查看配置',
        'menu-048',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2073',
        'asset:config:history-cleanup:edit',
        '编辑配置',
        'menu-048',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2074',
        'asset:config:custom-field:view',
        '查看自定义字段',
        'menu-049',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '2075',
        'asset:config:custom-field:edit',
        '编辑自定义字段',
        'menu-049',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.3 资产统计权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'btn-107',
        'asset:stats:view',
        '查看统计',
        'BUTTON',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.4 资产导入权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'btn-101',
        'asset:company:import',
        '导入公司',
        'BUTTON',
        'menu-031',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-102',
        'asset:domain:import',
        '导入主域名',
        'BUTTON',
        'menu-032',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-103',
        'asset:ip:import',
        '导入IP',
        'BUTTON',
        'menu-034',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-104',
        'asset:port:import',
        '导入端口',
        'BUTTON',
        'menu-035',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-105',
        'asset:subdomain:import',
        '导入子域名',
        'BUTTON',
        'menu-033',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-106',
        'asset:web:import',
        '导入Web',
        'BUTTON',
        'menu-036',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.5 空间测绘权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '3002',
        'search:query:execute',
        '执行搜索',
        'menu-051',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '3003',
        'search:query:import',
        '导入资产',
        'menu-051',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '3012',
        'search:engine:view',
        '查看配置',
        'menu-052',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '3013',
        'search:engine:edit',
        '编辑配置',
        'menu-052',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '3022',
        'search:syntax:view',
        '查看语法',
        'menu-053',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '3023',
        'search:syntax:edit',
        '编辑语法',
        'menu-053',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.5 工作流权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '4002',
        'workflow:config:view',
        '查看工作流',
        'menu-061',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '4003',
        'workflow:config:edit',
        '编辑工作流',
        'menu-061',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '4004',
        'workflow:config:execute',
        '执行工作流',
        'menu-061',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '4012',
        'workflow:tool:view',
        '查看工具',
        'menu-062',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '4013',
        'workflow:tool:edit',
        '编辑工具',
        'menu-062',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '4014',
        'workflow:tool:execute',
        '运行工具',
        'menu-062',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '4015',
        'workflow:tool:test',
        '测试工具',
        'menu-062',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '4022',
        'workflow:runs:view',
        '查看记录',
        'menu-063',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '4023',
        'workflow:runs:control',
        '控制执行',
        'menu-063',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.6 任务管理权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '5002',
        'task:list:view',
        '查看任务',
        'menu-064',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '5003',
        'task:list:edit',
        '编辑任务',
        'menu-064',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '5004',
        'task:list:execute',
        '执行任务',
        'menu-064',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.7 项目管理权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '6002',
        'project:list:view',
        '查看项目',
        'menu-020',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '6003',
        'project:list:edit',
        '编辑项目',
        'menu-020',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.8 节点管理权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '7002',
        'client:list:view',
        '查看节点',
        'menu-065',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '7003',
        'client:list:edit',
        '管理节点',
        'menu-065',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.9 AI助手权限
-- 2.10 MCP 权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '8072',
        'mcp:view',
        '查看MCP列表',
        '',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '8073',
        'mcp:execute',
        '调用MCP工具',
        '',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.11 资产追溯权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '9101',
        'history:view',
        '查看资产历史',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '9102',
        'history:rollback',
        '回滚资产版本',
        'menu-030',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '9002',
        'config-file:view',
        '查看文件',
        'menu-066',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '9003',
        'config-file:edit',
        '管理文件',
        'menu-066',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '9004',
        'config-file:download',
        '下载文件',
        'menu-066',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.11 通知中心权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        '10002',
        'notification:view',
        '查看通知',
        'menu-085',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        '10003',
        'notification:manage',
        '管理通知',
        'menu-085',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.12 文件权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'btn-110',
        'file:upload',
        '上传文件',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-111',
        'file:download',
        '下载文件',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-112',
        'file:report',
        '生成报告',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-113',
        'storage:policy:view',
        '查看存储策略',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- 2.13 Mock / 测试用例 / DSL 商店权限
INSERT INTO
    sys_permission (
        id,
        permission_code,
        permission_name,
        resource_type,
        menu_id,
        status,
        create_by,
        create_time
    )
VALUES (
        'btn-120',
        'mock:manage',
        '管理Mock文件',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-121',
        'mock:execute',
        '执行Mock测试',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-122',
        'test:case:view',
        '查看测试用例',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-123',
        'test:case:edit',
        '管理测试用例',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-124',
        'test:case:run',
        '运行测试用例',
        'BUTTON',
        'menu-095',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-125',
        'tool:registry:view',
        '查看DSL商店',
        'BUTTON',
        'menu-056',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-126',
        'tool:registry:edit',
        '管理DSL商店配置',
        'BUTTON',
        'menu-056',
        'ACTIVE',
        'admin',
        NOW()
    ),
    (
        'btn-127',
        'tool:registry:install',
        '安装DSL商店资源',
        'BUTTON',
        'menu-056',
        'ACTIVE',
        'admin',
        NOW()
    )
ON CONFLICT DO NOTHING;

-- =======================================================
-- 四、角色权限关联初始化 (sys_role_permission)
-- =======================================================

-- 4.1 超级管理员(SUPER_ADMIN, id=1) - 拥有所有权限
INSERT INTO
    sys_role_permission (
        id,
        role_id,
        permission_id,
        create_by,
        create_time
    )
SELECT
replace(gen_random_uuid()::text, '-', ''),
    '1',
    id,
    'admin',
    NOW()
FROM sys_permission;

-- 4.2 管理员(ADMIN, id=2) - 除系统管理按钮权限外的所有权限
INSERT INTO
    sys_role_permission (
        id,
        role_id,
        permission_id,
        create_by,
        create_time
    )
SELECT
replace(gen_random_uuid()::text, '-', ''),
    '2',
    id,
    'admin',
    NOW()
FROM sys_permission
WHERE
    -- 所有菜单权限
    resource_type = 'MENU'
    -- 非系统管理的按钮权限
    OR (
        permission_code NOT LIKE 'system:%'
        AND resource_type != 'MENU'
    )
    -- 部门查看权限
    OR permission_code = 'system:dept:view'
    OR permission_code = 'system:dept:edit';

-- 4.3 普通用户(USER, id=3) - 基础菜单权限
INSERT INTO
    sys_role_permission (
        id,
        role_id,
        permission_id,
        create_by,
        create_time
    )
SELECT
replace(gen_random_uuid()::text, '-', ''),
    '3',
    id,
    'admin',
    NOW()
FROM sys_permission
WHERE
    -- 控制台
    permission_code = 'dashboard'
    -- MCP
    OR permission_code LIKE 'mcp%'
    -- 项目管理
    OR permission_code = 'project'
    -- 资产管理
    OR permission_code = 'asset'
    OR permission_code LIKE 'asset:company'
    OR permission_code LIKE 'asset:domain'
    OR permission_code LIKE 'asset:subdomain'
    OR permission_code LIKE 'asset:ip'
    OR permission_code LIKE 'asset:port'
    OR permission_code LIKE 'asset:web'
    OR permission_code LIKE 'asset:api'
    OR permission_code LIKE 'asset:vul'
    -- 空间测绘
    OR permission_code = 'search'
    OR permission_code LIKE 'search:%'
    -- 查看权限
    OR permission_code LIKE '%:view'
    OR permission_code LIKE '%:query';

-- System Initialization Assets --



INSERT INTO
    testnet_project (
        id,
        project_name,
        comment,
        create_time
    )
VALUES (
        'proj_prod',
        '核心生产环境',
        '外部可见的生产业务资产',
        '2026-04-01 16:15:04'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_domain (
        id,
        domain,
        project_id,
        company_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'b648a786-121b-4962-b44d-600d11bae827',
        'testnet-dev.io',
        'proj_prod',
        'comp_dev',
        '研发域名',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_domain (
        id,
        domain,
        project_id,
        company_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '1c3d8900-1009-43b6-85c5-72ffb7727bb1',
        'testnet-prod.com',
        'proj_prod',
        'comp_overseas',
        '生产主域',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_domain (
        id,
        domain,
        project_id,
        company_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '9756d667-0021-450a-afca-3798be0987b2',
        'example-corp.net',
        'proj_prod',
        'comp_root',
        '合作伙伴',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_domain (
        id,
        domain,
        project_id,
        company_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'baa6ed67-7683-4743-ac13-8f4d97b77cdf',
        'shadow-project.org',
        'proj_prod',
        'comp_dev',
        '影子资产',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '44d2e534-459f-4e07-a2f3-76f2bcd3e10a',
        'www.testnet-dev.io',
        'b648a786-121b-4962-b44d-600d11bae827',
        'proj_prod',
        'Web,Staging',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '506f25d1-1841-4fe8-91ad-8415c8fdf00b',
        'api.testnet-dev.io',
        'b648a786-121b-4962-b44d-600d11bae827',
        'proj_prod',
        'Internal,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'b631fa38-1445-4cf6-9209-ed0e2964c18c',
        'dev.testnet-dev.io',
        'b648a786-121b-4962-b44d-600d11bae827',
        'proj_prod',
        'Web,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'cda5e8a9-6f50-455c-9414-9d6597ea28b8',
        'test.testnet-dev.io',
        'b648a786-121b-4962-b44d-600d11bae827',
        'proj_prod',
        'API,Staging',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '3e34ec80-e345-4884-8e0e-f94136b8abc9',
        'www.testnet-prod.com',
        '1c3d8900-1009-43b6-85c5-72ffb7727bb1',
        'proj_prod',
        'Web,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '90a68c75-c430-447a-8158-58f8984521c8',
        'api.testnet-prod.com',
        '1c3d8900-1009-43b6-85c5-72ffb7727bb1',
        'proj_prod',
        'API,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'd561b18c-5285-45bc-9e07-3318c53059ab',
        'dev.testnet-prod.com',
        '1c3d8900-1009-43b6-85c5-72ffb7727bb1',
        'proj_prod',
        'Web,Staging',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '195b65ae-df2b-4b94-b54a-bb7218f016a3',
        'test.testnet-prod.com',
        '1c3d8900-1009-43b6-85c5-72ffb7727bb1',
        'proj_prod',
        'Internal,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'e2eaf7eb-e28f-44bb-ac77-7233374ab4fa',
        'm.testnet-prod.com',
        '1c3d8900-1009-43b6-85c5-72ffb7727bb1',
        'proj_prod',
        'API,Staging',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '1bf3aa3b-ad49-494c-974b-c8c84a1b36a6',
        'static.testnet-prod.com',
        '1c3d8900-1009-43b6-85c5-72ffb7727bb1',
        'proj_prod',
        'Public,Staging',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '9053106c-5392-48ea-a157-2f3f9149aefa',
        'www.example-corp.net',
        '9756d667-0021-450a-afca-3798be0987b2',
        'proj_prod',
        'Internal,Staging',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '55679d7e-b470-4a63-b42e-ade196a093e3',
        'api.example-corp.net',
        '9756d667-0021-450a-afca-3798be0987b2',
        'proj_prod',
        'Public,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'a07cbfa9-9f4e-4d69-80c3-f74f584628c5',
        'dev.example-corp.net',
        '9756d667-0021-450a-afca-3798be0987b2',
        'proj_prod',
        'API,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'fd245375-a9f0-4028-b89d-0890e829f96e',
        'test.example-corp.net',
        '9756d667-0021-450a-afca-3798be0987b2',
        'proj_prod',
        'API,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '87a387b9-280d-4faf-9993-7fee5f38e5e9',
        'www.shadow-project.org',
        'baa6ed67-7683-4743-ac13-8f4d97b77cdf',
        'proj_prod',
        'API,Staging',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '1609d3a0-2d39-4199-b793-f2fd53a899c1',
        'api.shadow-project.org',
        'baa6ed67-7683-4743-ac13-8f4d97b77cdf',
        'proj_prod',
        'Web,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_sub_domain (
        id,
        sub_domain,
        domain_id,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '70342e50-4d6b-4d9b-9d82-15066dad47ed',
        'dev.shadow-project.org',
        'baa6ed67-7683-4743-ac13-8f4d97b77cdf',
        'proj_prod',
        'API,Active',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '6ebe9f2d-a625-4bbf-82eb-18612f2b1a97',
        '10.0.0.1',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '82231bbb-9839-446a-ad9b-f4037215533c',
        '10.0.0.2',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '5050e3c4-5202-4317-96c5-af90c21dd1fe',
        '10.0.0.3',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'a26678c4-1ea1-4b5d-8ca8-b9c94a573950',
        '10.0.0.4',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'dce5aa6f-4950-470d-b9c1-5f107fefcefd',
        '10.0.0.5',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'e2c49b41-49ca-478f-a9e7-5217fe11b65c',
        '10.0.0.6',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '6716322c-2f26-4130-bac2-d72f4c06f305',
        '10.0.0.7',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'ff7457ab-ac48-401a-9818-546edd98c31e',
        '10.0.0.8',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '3f0f9086-2206-4e0b-ad81-e84e47488ca0',
        '10.0.0.9',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '0ddadf01-491d-42de-832c-701952683262',
        '10.0.0.10',
        'proj_prod',
        'IDC',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'adcb85af-9e09-46cc-b6df-ba35f1258fc7',
        '1.2.3.11',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '6512c7d2-97c6-4215-9923-8a9234ad7cb6',
        '1.2.3.12',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '1a044573-0894-447d-817d-56f64fb44484',
        '1.2.3.13',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'a73a9660-903b-4289-9a98-e0e76e246212',
        '1.2.3.14',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '902a6f56-ea09-4811-9933-09a8c63cb86c',
        '1.2.3.15',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'e6e3d3c8-a4b6-454f-b397-789e6a9eb2d0',
        '1.2.3.16',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'ef57f7b9-b899-4d04-94f7-8fa8c19a82f1',
        '1.2.3.17',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '55e59a0d-2e18-456e-9b9b-7886ed39cb97',
        '1.2.3.18',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'e8e5a339-fdb8-4465-bf4b-63ed98018f2d',
        '1.2.3.19',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip (
        id,
        ip,
        project_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'efb3c49a-a2ea-4ac8-b0f7-885a5e13b26d',
        '1.2.3.20',
        'proj_prod',
        'Public,Aliyun',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'bb3b6e2b-50bf-4527-a473-81f28acc1e2b',
        '44d2e534-459f-4e07-a2f3-76f2bcd3e10a',
        '6512c7d2-97c6-4215-9923-8a9234ad7cb6'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '64ddedf5-70a3-438a-a730-0a004e3ea4ee',
        '506f25d1-1841-4fe8-91ad-8415c8fdf00b',
        'ef57f7b9-b899-4d04-94f7-8fa8c19a82f1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '574d1434-ca22-4bc6-bfd7-25fd96c757ca',
        'b631fa38-1445-4cf6-9209-ed0e2964c18c',
        'dce5aa6f-4950-470d-b9c1-5f107fefcefd'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '65343465-7b97-4833-bdaa-d41b070060bd',
        'b631fa38-1445-4cf6-9209-ed0e2964c18c',
        '6716322c-2f26-4130-bac2-d72f4c06f305'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '318c866a-1ed8-4578-af95-13004548a35d',
        'cda5e8a9-6f50-455c-9414-9d6597ea28b8',
        '55e59a0d-2e18-456e-9b9b-7886ed39cb97'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'ab00610c-a28a-43c3-9cc2-97ce8e5560ca',
        '3e34ec80-e345-4884-8e0e-f94136b8abc9',
        'dce5aa6f-4950-470d-b9c1-5f107fefcefd'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'ca7ebccd-00dc-4a4a-a55b-13f3975c99c5',
        '90a68c75-c430-447a-8158-58f8984521c8',
        '0ddadf01-491d-42de-832c-701952683262'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '798c8c81-8ac0-455d-b0c1-2da2cc6e58d8',
        'd561b18c-5285-45bc-9e07-3318c53059ab',
        '902a6f56-ea09-4811-9933-09a8c63cb86c'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '41f5f5b3-2ea3-40ee-aef1-4792ffc4d869',
        '195b65ae-df2b-4b94-b54a-bb7218f016a3',
        '55e59a0d-2e18-456e-9b9b-7886ed39cb97'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'a4bd6996-5ac8-41d9-91b0-684c6c8021e5',
        '195b65ae-df2b-4b94-b54a-bb7218f016a3',
        '3f0f9086-2206-4e0b-ad81-e84e47488ca0'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '7f0e9ee7-6348-430e-9aac-d7f73cd1eed7',
        'e2eaf7eb-e28f-44bb-ac77-7233374ab4fa',
        'efb3c49a-a2ea-4ac8-b0f7-885a5e13b26d'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '7605fb4a-bdd3-49c6-a4b6-6fbf0389ec0d',
        'e2eaf7eb-e28f-44bb-ac77-7233374ab4fa',
        'ef57f7b9-b899-4d04-94f7-8fa8c19a82f1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'eaa0b379-405b-4d20-a8b9-ea374650d961',
        '1bf3aa3b-ad49-494c-974b-c8c84a1b36a6',
        'e2c49b41-49ca-478f-a9e7-5217fe11b65c'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '81d25191-72be-4d7b-9383-56ebc424530a',
        '9053106c-5392-48ea-a157-2f3f9149aefa',
        'dce5aa6f-4950-470d-b9c1-5f107fefcefd'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'c8a13dfb-c12f-4414-93f3-940b629796db',
        '55679d7e-b470-4a63-b42e-ade196a093e3',
        '1a044573-0894-447d-817d-56f64fb44484'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '973147b8-709c-4acc-8700-3f91682643e5',
        '55679d7e-b470-4a63-b42e-ade196a093e3',
        '6ebe9f2d-a625-4bbf-82eb-18612f2b1a97'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '59353f51-5b12-4eae-bdd1-e1dafdc60a13',
        'a07cbfa9-9f4e-4d69-80c3-f74f584628c5',
        '55e59a0d-2e18-456e-9b9b-7886ed39cb97'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '6cdc6a41-9c09-4fe9-873e-a0f7ee42649c',
        'a07cbfa9-9f4e-4d69-80c3-f74f584628c5',
        '5050e3c4-5202-4317-96c5-af90c21dd1fe'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'f8cf69b0-c82f-4164-bf0e-a9ea82d15bfd',
        'fd245375-a9f0-4028-b89d-0890e829f96e',
        '0ddadf01-491d-42de-832c-701952683262'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '9317ef1a-9dd5-4a9b-b25b-64d3eea7b767',
        'fd245375-a9f0-4028-b89d-0890e829f96e',
        'efb3c49a-a2ea-4ac8-b0f7-885a5e13b26d'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'a0cef6ed-96c8-46ee-a704-35afe90e57c2',
        '87a387b9-280d-4faf-9993-7fee5f38e5e9',
        'e6e3d3c8-a4b6-454f-b397-789e6a9eb2d0'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '701626a5-e8cd-4ce5-bcb3-861ad650ce4a',
        '1609d3a0-2d39-4199-b793-f2fd53a899c1',
        '55e59a0d-2e18-456e-9b9b-7886ed39cb97'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        '78647a06-9042-4784-96e9-cecf7f03a613',
        '1609d3a0-2d39-4199-b793-f2fd53a899c1',
        'adcb85af-9e09-46cc-b6df-ba35f1258fc7'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'a80de61c-4152-40c2-9169-35370d645378',
        '70342e50-4d6b-4d9b-9d82-15066dad47ed',
        '1a044573-0894-447d-817d-56f64fb44484'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_ip_sub_domain (id, subdomain_id, ip_id)
VALUES (
        'cbdd7bf3-3bbb-475f-a20e-7d5f9beac645',
        '70342e50-4d6b-4d9b-9d82-15066dad47ed',
        'e2c49b41-49ca-478f-a9e7-5217fe11b65c'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '2b6a06f6-85c6-4792-bacb-4da34f9c722e',
        8080,
        '6ebe9f2d-a625-4bbf-82eb-18612f2b1a97',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '60bb9ae9-be62-4102-bb0d-fd01a2c15833',
        22,
        '6ebe9f2d-a625-4bbf-82eb-18612f2b1a97',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '7064e2f2-9ddf-41dc-b498-ca9ac3662020',
        6379,
        '6ebe9f2d-a625-4bbf-82eb-18612f2b1a97',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'c81ff35f-fc8f-444c-a0d6-77481218b975',
        8443,
        '6ebe9f2d-a625-4bbf-82eb-18612f2b1a97',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'eb4cc24e-8819-4358-b59f-da6b00381680',
        22,
        '82231bbb-9839-446a-ad9b-f4037215533c',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '2319c571-f313-4ad1-bdeb-4d41de1e3e44',
        6379,
        '82231bbb-9839-446a-ad9b-f4037215533c',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'd28b7d33-47c8-4822-9fb9-9065c5d951a4',
        161,
        '82231bbb-9839-446a-ad9b-f4037215533c',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '510f6d1b-e1b9-4fe9-b9fe-88ec90edc2df',
        3306,
        '5050e3c4-5202-4317-96c5-af90c21dd1fe',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '40f78ec5-282e-467e-a2fd-eeced63b1224',
        80,
        'a26678c4-1ea1-4b5d-8ca8-b9c94a573950',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '63221b08-46ca-4c85-ae2b-48f65f7edbb6',
        6379,
        'a26678c4-1ea1-4b5d-8ca8-b9c94a573950',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'c18278fd-f884-46f2-a8c8-6ca59f464130',
        443,
        'a26678c4-1ea1-4b5d-8ca8-b9c94a573950',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '558f2461-3424-4381-adf6-b8e3d465d523',
        8080,
        'a26678c4-1ea1-4b5d-8ca8-b9c94a573950',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '240bd17b-6320-4dee-98cc-8d9776bb84a3',
        3306,
        'dce5aa6f-4950-470d-b9c1-5f107fefcefd',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '05bd500c-7a1c-4c8a-be43-b51689718288',
        443,
        'dce5aa6f-4950-470d-b9c1-5f107fefcefd',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'b38f109e-3ee1-4dae-acae-5207fe435e7d',
        6379,
        'dce5aa6f-4950-470d-b9c1-5f107fefcefd',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '33777f75-6aaa-4753-b241-65c0cbc4803a',
        8080,
        'dce5aa6f-4950-470d-b9c1-5f107fefcefd',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'e0832555-0e36-45ba-bc98-dbf1dc3af117',
        161,
        'e2c49b41-49ca-478f-a9e7-5217fe11b65c',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'e5ee1691-e1ea-4b62-9bb7-8f283289fa44',
        3306,
        '6716322c-2f26-4130-bac2-d72f4c06f305',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'e69ddf8d-6f83-426d-9e7f-ada7c63119b0',
        6379,
        '6716322c-2f26-4130-bac2-d72f4c06f305',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'adcb03b5-ea3f-41b9-ae4d-d34aa303c2f0',
        8080,
        '6716322c-2f26-4130-bac2-d72f4c06f305',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '0190631f-2936-41bc-8fff-e4ac35665558',
        443,
        '6716322c-2f26-4130-bac2-d72f4c06f305',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '47720a03-390a-4b09-9117-edebd0faac07',
        3306,
        'ff7457ab-ac48-401a-9818-546edd98c31e',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'bbdd517b-83d6-4e46-becd-2082c3845942',
        80,
        'ff7457ab-ac48-401a-9818-546edd98c31e',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '5343f1b9-f4a6-48a4-9105-2f2b03807af6',
        6379,
        'ff7457ab-ac48-401a-9818-546edd98c31e',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'e9cc769d-1bf0-49fb-9edf-cc680cbffa24',
        8443,
        'ff7457ab-ac48-401a-9818-546edd98c31e',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'da0b823d-7d24-4039-be7b-4162ff97a038',
        3306,
        '3f0f9086-2206-4e0b-ad81-e84e47488ca0',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '8ab3c1f8-7a4a-4094-b535-c7e3e0ca7d15',
        8080,
        '3f0f9086-2206-4e0b-ad81-e84e47488ca0',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '861f02d4-7123-4bf7-844b-efe3cefea3a5',
        8443,
        '3f0f9086-2206-4e0b-ad81-e84e47488ca0',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '30597f9f-eccd-43f5-afb0-8c302ef49811',
        22,
        '0ddadf01-491d-42de-832c-701952683262',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '0965075f-acc3-4504-8807-ca659d2fd57f',
        443,
        '0ddadf01-491d-42de-832c-701952683262',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '76c5753a-03ba-4630-8e6c-2598906fd014',
        8080,
        '0ddadf01-491d-42de-832c-701952683262',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '17c4dc17-1d11-4cbf-b7a7-4818c2a8fa54',
        80,
        'adcb85af-9e09-46cc-b6df-ba35f1258fc7',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '541c39b6-ab54-41d3-b99d-f01601e47717',
        443,
        '6512c7d2-97c6-4215-9923-8a9234ad7cb6',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'c28bb5f4-0767-494f-8bc8-071dd7a3620f',
        443,
        '1a044573-0894-447d-817d-56f64fb44484',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '5469457a-980c-427e-b299-130efd21cc61',
        161,
        '1a044573-0894-447d-817d-56f64fb44484',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '243d33be-c502-41ef-a5f7-1b1f448e4f04',
        8080,
        '1a044573-0894-447d-817d-56f64fb44484',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'fde6229c-b505-4b3b-983f-308778ca4d59',
        6379,
        'a73a9660-903b-4289-9a98-e0e76e246212',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '4e4ca4a1-779b-4be7-87f7-cafc08483dd0',
        161,
        '902a6f56-ea09-4811-9933-09a8c63cb86c',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '610941c6-bc92-4974-b689-081058bfb3cb',
        80,
        'e6e3d3c8-a4b6-454f-b397-789e6a9eb2d0',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '33cd7aa7-668c-4004-ac10-93dd240b1ed6',
        161,
        'e6e3d3c8-a4b6-454f-b397-789e6a9eb2d0',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'bca51791-aa22-47db-84b9-d9c4c7ad328d',
        8080,
        'ef57f7b9-b899-4d04-94f7-8fa8c19a82f1',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'bec2569b-37c7-4539-8617-0e2a0e866b24',
        80,
        'ef57f7b9-b899-4d04-94f7-8fa8c19a82f1',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '116e3195-5407-456e-a286-22851b76d1e2',
        6379,
        '55e59a0d-2e18-456e-9b9b-7886ed39cb97',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'db94bf4a-3a2b-49b1-9209-3dfaf509c4ba',
        3306,
        '55e59a0d-2e18-456e-9b9b-7886ed39cb97',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'd4cbcae0-6c5f-42f3-86fd-5e9d060dc1e8',
        8443,
        '55e59a0d-2e18-456e-9b9b-7886ed39cb97',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '029703f4-5b3a-435c-99d8-0956ba12e02e',
        8080,
        'e8e5a339-fdb8-4465-bf4b-63ed98018f2d',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'b4524d2d-c4a8-4ce3-a556-8c086e235716',
        8443,
        'efb3c49a-a2ea-4ac8-b0f7-885a5e13b26d',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'afb32725-d101-4682-ae4f-099c6d9e6861',
        22,
        'efb3c49a-a2ea-4ac8-b0f7-885a5e13b26d',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        '419379da-3d8c-4838-aeab-e728fc1d9bee',
        443,
        'efb3c49a-a2ea-4ac8-b0f7-885a5e13b26d',
        'proj_prod',
        'Service',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_port (
        id,
        port,
        ip_id,
        project_id,
        asset_label,
        create_time,
        status,
        is_open
    )
VALUES (
        'ba0755ef-6235-4f28-a1b7-0b7ed9497af3',
        6379,
        'efb3c49a-a2ea-4ac8-b0f7-885a5e13b26d',
        'proj_prod',
        'Sensitive',
        '2026-04-01 16:15:04',
        'ACTIVE',
        '1'
    )
ON CONFLICT DO NOTHING;




INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '5fc39144-131c-49b9-8b73-98207f99dc27',
        'https://api.example-corp.net:8443',
        'c81ff35f-fc8f-444c-a0d6-77481218b975',
        'proj_prod',
        '55679d7e-b470-4a63-b42e-ade196a093e3',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '1407c051-4641-46de-ac5e-7fd8366d1850',
        'https://dev.testnet-dev.io',
        '05bd500c-7a1c-4c8a-be43-b51689718288',
        'proj_prod',
        'b631fa38-1445-4cf6-9209-ed0e2964c18c',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'b547f02d-ae56-426e-97bd-a90f9341bc9a',
        'http://dev.testnet-dev.io:8080',
        '33777f75-6aaa-4753-b241-65c0cbc4803a',
        'proj_prod',
        'b631fa38-1445-4cf6-9209-ed0e2964c18c',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '188a6b6c-88ee-4a68-866b-8e199259f8b8',
        'http://dev.testnet-dev.io:8080',
        'adcb03b5-ea3f-41b9-ae4d-d34aa303c2f0',
        'proj_prod',
        'b631fa38-1445-4cf6-9209-ed0e2964c18c',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'a2309574-798f-4b0f-9a63-bf5e47ddf913',
        'https://dev.testnet-dev.io',
        '0190631f-2936-41bc-8fff-e4ac35665558',
        'proj_prod',
        'b631fa38-1445-4cf6-9209-ed0e2964c18c',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '849dfb1f-8f72-4896-8b2b-9e5fe2642b36',
        'http://test.testnet-prod.com:8080',
        '8ab3c1f8-7a4a-4094-b535-c7e3e0ca7d15',
        'proj_prod',
        '195b65ae-df2b-4b94-b54a-bb7218f016a3',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '7b46af8e-b787-45d5-bd0a-3218bebc9cc5',
        'https://test.testnet-prod.com:8443',
        '861f02d4-7123-4bf7-844b-efe3cefea3a5',
        'proj_prod',
        '195b65ae-df2b-4b94-b54a-bb7218f016a3',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'b0de3aab-6f3c-40d0-83d1-6176526b30cf',
        'https://api.testnet-prod.com',
        '0965075f-acc3-4504-8807-ca659d2fd57f',
        'proj_prod',
        '90a68c75-c430-447a-8158-58f8984521c8',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '0e20cd1e-85c5-468a-9363-ea49718c31cc',
        'http://api.testnet-prod.com:8080',
        '76c5753a-03ba-4630-8e6c-2598906fd014',
        'proj_prod',
        '90a68c75-c430-447a-8158-58f8984521c8',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '6be92798-9882-46e8-85b7-e97d57c75e93',
        'http://api.shadow-project.org',
        '17c4dc17-1d11-4cbf-b7a7-4818c2a8fa54',
        'proj_prod',
        '1609d3a0-2d39-4199-b793-f2fd53a899c1',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'b41650c9-0857-4be0-bd47-fcc283f338b6',
        'https://www.testnet-dev.io',
        '541c39b6-ab54-41d3-b99d-f01601e47717',
        'proj_prod',
        '44d2e534-459f-4e07-a2f3-76f2bcd3e10a',
        'Marketing',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'dd996dbf-98d0-441e-8044-86bc686ff2ee',
        'https://api.example-corp.net',
        'c28bb5f4-0767-494f-8bc8-071dd7a3620f',
        'proj_prod',
        '55679d7e-b470-4a63-b42e-ade196a093e3',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '532a50dd-6c14-415c-b82b-a258f94a8ae5',
        'http://api.example-corp.net:8080',
        '243d33be-c502-41ef-a5f7-1b1f448e4f04',
        'proj_prod',
        '55679d7e-b470-4a63-b42e-ade196a093e3',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '5c4b8ec3-a6be-4b0d-986c-81f11418b972',
        'http://www.shadow-project.org',
        '610941c6-bc92-4974-b689-081058bfb3cb',
        'proj_prod',
        '87a387b9-280d-4faf-9993-7fee5f38e5e9',
        'Marketing',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '6fba799f-7de3-4aa3-9163-7aff99940a9d',
        'http://api.testnet-dev.io:8080',
        'bca51791-aa22-47db-84b9-d9c4c7ad328d',
        'proj_prod',
        '506f25d1-1841-4fe8-91ad-8415c8fdf00b',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'ba4fd16b-1236-477e-9399-9e0c5cfad3f5',
        'http://api.testnet-dev.io',
        'bec2569b-37c7-4539-8617-0e2a0e866b24',
        'proj_prod',
        '506f25d1-1841-4fe8-91ad-8415c8fdf00b',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '7473a3ef-53a3-49b9-a3af-b2abd0c36142',
        'https://test.testnet-dev.io:8443',
        'd4cbcae0-6c5f-42f3-86fd-5e9d060dc1e8',
        'proj_prod',
        'cda5e8a9-6f50-455c-9414-9d6597ea28b8',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        '269142f7-0383-47ce-b82f-43dabbe3b35e',
        'https://m.testnet-prod.com:8443',
        'b4524d2d-c4a8-4ce3-a556-8c086e235716',
        'proj_prod',
        'e2eaf7eb-e28f-44bb-ac77-7233374ab4fa',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_web (
        id,
        web_url,
        port_id,
        project_id,
        subdomain_id,
        asset_label,
        create_time,
        status
    )
VALUES (
        'a03ccae5-82fa-43bc-9764-a8428108218d',
        'https://m.testnet-prod.com',
        '419379da-3d8c-4838-aeab-e728fc1d9bee',
        'proj_prod',
        'e2eaf7eb-e28f-44bb-ac77-7233374ab4fa',
        'Infrastructure',
        '2026-04-01 16:15:04',
        'ACTIVE'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_vul (
        id,
        asset_type,
        asset_id,
        web_id,
        project_id,
        vul_name,
        severity,
        asset_label,
        create_time,
        status,
        vul_status
    )
VALUES (
        '45646a83-7d77-4ba7-8165-a1d0d250e8ab',
        'web',
        'b0de3aab-6f3c-40d0-83d1-6176526b30cf',
        'b0de3aab-6f3c-40d0-83d1-6176526b30cf',
        'proj_prod',
        'SQL Injection',
        'MEDIUM',
        'Confirmed',
        '2026-04-01 16:15:04',
        'ACTIVE',
        'OPEN'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_vul (
        id,
        asset_type,
        asset_id,
        web_id,
        project_id,
        vul_name,
        severity,
        asset_label,
        create_time,
        status,
        vul_status
    )
VALUES (
        'd748e616-9a98-4cf6-b5cb-a03e82645080',
        'web',
        '1407c051-4641-46de-ac5e-7fd8366d1850',
        '1407c051-4641-46de-ac5e-7fd8366d1850',
        'proj_prod',
        'Unauthorized Access',
        'HIGH',
        'Confirmed',
        '2026-04-01 16:15:04',
        'ACTIVE',
        'OPEN'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_vul (
        id,
        asset_type,
        asset_id,
        web_id,
        project_id,
        vul_name,
        severity,
        asset_label,
        create_time,
        status,
        vul_status
    )
VALUES (
        'c7d8347d-4b92-4165-803c-4a74781a1b1c',
        'web',
        '6fba799f-7de3-4aa3-9163-7aff99940a9d',
        '6fba799f-7de3-4aa3-9163-7aff99940a9d',
        'proj_prod',
        'SQL Injection',
        'MEDIUM',
        'Confirmed',
        '2026-04-01 16:15:04',
        'ACTIVE',
        'OPEN'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_vul (
        id,
        asset_type,
        asset_id,
        web_id,
        project_id,
        vul_name,
        severity,
        asset_label,
        create_time,
        status,
        vul_status
    )
VALUES (
        'c13a71b1-9dc9-4037-9a15-a6b72e369678',
        'web',
        'b547f02d-ae56-426e-97bd-a90f9341bc9a',
        'b547f02d-ae56-426e-97bd-a90f9341bc9a',
        'proj_prod',
        'Sensitive Info Leak',
        'HIGH',
        'Confirmed',
        '2026-04-01 16:15:04',
        'ACTIVE',
        'OPEN'
    )
ON CONFLICT DO NOTHING;

INSERT INTO
    testnet_asset_vul (
        id,
        asset_type,
        asset_id,
        web_id,
        project_id,
        vul_name,
        severity,
        asset_label,
        create_time,
        status,
        vul_status
    )
VALUES (
        '160f3e9b-abf9-4f19-93e7-de64b3052c4b',
        'web',
        '5c4b8ec3-a6be-4b0d-986c-81f11418b972',
        '5c4b8ec3-a6be-4b0d-986c-81f11418b972',
        'proj_prod',
        'Sensitive Info Leak',
        'HIGH',
        'Confirmed',
        '2026-04-01 16:15:04',
        'ACTIVE',
        'OPEN'
    )
ON CONFLICT DO NOTHING;

-- Extracted indexes from CREATE TABLE (for load-order safety)
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_retry ON testnet_asset_task (task_status, retry_count, max_retries, last_retry_time);
CREATE INDEX IF NOT EXISTS idx_testnet_asset_task_project_hash_status ON testnet_asset_task (project_id, params_hash, task_status);
CREATE INDEX IF NOT EXISTS idx_testnet_domain_event_aggregate ON testnet_domain_event (aggregate_type, aggregate_id);

-- ============================================================
-- Foreign Key constraints (moved to end for load-order safety)
-- PostgreSQL 要求被引用表先于 FK 创建，故将前向引用 FK 置于此处
-- ============================================================
ALTER TABLE testnet_asset_ip_sub_domain ADD CONSTRAINT fk_ip_subdomain_to_subdomain FOREIGN KEY (subdomain_id) REFERENCES testnet_asset_sub_domain (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_vul ADD CONSTRAINT fk_vul_to_web FOREIGN KEY (web_id) REFERENCES testnet_asset_web (id) ON DELETE CASCADE ON UPDATE RESTRICT;

-- Added missing cascade foreign key constraints for PostgreSQL migration
ALTER TABLE sys_role_permission ADD CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES sys_role (id) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE sys_role_permission ADD CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES sys_permission (id) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE sys_user_role ADD CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES sys_user (id) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE sys_user_role ADD CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES sys_role (id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE testnet_asset_company ADD CONSTRAINT fk_project_id_company FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_domain ADD CONSTRAINT fk_project_id_domain FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_ip ADD CONSTRAINT fk_project_id_ip FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_sub_domain ADD CONSTRAINT fk_project_id_sub_domain FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_port ADD CONSTRAINT fk_project_id_port FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_web ADD CONSTRAINT fk_project_id_web FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_api_tree ADD CONSTRAINT fk_project_id_api_tree FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_api ADD CONSTRAINT fk_project_id_api FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_vul ADD CONSTRAINT fk_project_id_vul FOREIGN KEY (project_id) REFERENCES testnet_project (id) ON DELETE CASCADE ON UPDATE RESTRICT;

ALTER TABLE testnet_asset_ip_sub_domain ADD CONSTRAINT fk_ip_subdomain_to_ip FOREIGN KEY (ip_id) REFERENCES testnet_asset_ip (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_port ADD CONSTRAINT fk_port_to_ip FOREIGN KEY (ip_id) REFERENCES testnet_asset_ip (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_sub_domain ADD CONSTRAINT fk_subdomain_to_domain FOREIGN KEY (domain_id) REFERENCES testnet_asset_domain (id) ON DELETE CASCADE ON UPDATE RESTRICT;

ALTER TABLE testnet_asset_vul ADD CONSTRAINT fk_vul_to_ip FOREIGN KEY (ip_id) REFERENCES testnet_asset_ip (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_vul ADD CONSTRAINT fk_vul_to_domain FOREIGN KEY (domain_id) REFERENCES testnet_asset_domain (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_vul ADD CONSTRAINT fk_vul_to_subdomain FOREIGN KEY (subdomain_id) REFERENCES testnet_asset_sub_domain (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_vul ADD CONSTRAINT fk_vul_to_port FOREIGN KEY (port_id) REFERENCES testnet_asset_port (id) ON DELETE CASCADE ON UPDATE RESTRICT;

ALTER TABLE testnet_asset_web ADD CONSTRAINT fk_web_to_port FOREIGN KEY (port_id) REFERENCES testnet_asset_port (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_web ADD CONSTRAINT fk_web_to_subdomain FOREIGN KEY (subdomain_id) REFERENCES testnet_asset_sub_domain (id) ON DELETE CASCADE ON UPDATE RESTRICT;

ALTER TABLE testnet_asset_api_tree ADD CONSTRAINT fk_api_tree_to_web FOREIGN KEY (asset_web_id) REFERENCES testnet_asset_web (id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE testnet_asset_api ADD CONSTRAINT fk_api_to_web_tree FOREIGN KEY (asset_web_tree_id) REFERENCES testnet_asset_api_tree (id) ON DELETE CASCADE ON UPDATE RESTRICT;

ALTER TABLE testnet_task_execution_log ADD CONSTRAINT fk_execution_log_task FOREIGN KEY (task_id) REFERENCES testnet_asset_task (id) ON DELETE CASCADE ON UPDATE RESTRICT;

-- Billiard Salon -- dimensional warehouse (galaxy schema) + initial full load
-- RUN ORDER: 3 of 4. Run after normalised.sql (and bill_timestamps_triggers.sql).
-- 5 dimensions, 2 fact tables, 1 bridge. Initial load via INSERT...SELECT.
-- Re-runnable incremental sync lives in bill_etl_merge.sql (run 4).

drop table if exists billiard.fact_session_service
drop table if exists billiard.fact_payment
drop table if exists billiard.fact_session
drop table if exists billiard.dim_service
drop table if exists billiard.dim_billiardtable
drop table if exists billiard.dim_staff
drop table if exists billiard.dim_customer
drop table if exists billiard.dim_date

go

create table billiard.dim_customer (
    customer_key int identity(1,1) primary key,
    customer_id int,
    customer_name varchar(255),
    customer_email varchar(255),
    customer_phone varchar(50)
)

create table billiard.dim_staff (
    staff_key int identity(1,1) primary key,
    staff_id int,
    staff_name varchar(255),
    staff_role varchar(100)
)
create table billiard.dim_billiardtable (
    table_key int identity(1,1) primary key,
    table_number int,
    table_type varchar(50),
    hourly_rate decimal(10, 2)
)

create table billiard.dim_service (
    service_key int identity(1,1) primary key,
    service_id int,
    service_name varchar(100),
    service_cost decimal(10, 2)
)

create table billiard.dim_date (
    date_key int primary key,
    full_date date,
    cal_year int,
    cal_month int,
    cal_day int
)

create table billiard.fact_session (
    session_key int identity(1,1) primary key,
    session_id int,
    customer_key int,
    table_key int,
    staff_key int,
    start_date_key int,
    end_date_key int,
    total_time_hours float,
    amount_billed decimal(10, 2),
    foreign key (customer_key) references billiard.dim_customer(customer_key),
    foreign key (table_key) references billiard.dim_billiardtable(table_key),
    foreign key (staff_key) references billiard.dim_staff(staff_key),
    foreign key (start_date_key) references billiard.dim_date(date_key),
    foreign key (end_date_key) references billiard.dim_date(date_key)
)


create table billiard.fact_payment (
    payment_key int identity(1,1) primary key,
    payment_id int,
    session_key int,
    payment_date_key int,
    payment_amount decimal(10, 2),
    payment_status varchar(50),
    foreign key (session_key) references billiard.fact_session(session_key),
    foreign key (payment_date_key) references billiard.dim_date(date_key)
)


create table billiard.fact_session_service (
    session_key int,
    service_key int,
    service_cost decimal(10, 2),
    primary key (session_key, service_key),
    foreign key (session_key) references billiard.fact_session(session_key),
    foreign key (service_key) references billiard.dim_service(service_key)
)

go



insert into billiard.dim_customer (customer_id, customer_name, customer_email, customer_phone)
select customerid, customername, customeremail, customerphone
from billiard.customers

insert into billiard.dim_staff (staff_id, staff_name, staff_role)
select staffid, staffname, staffrole
from billiard.staff

insert into billiard.dim_billiardtable (table_number, table_type, hourly_rate)
select b.tablenumber, t.typename, b.hourlyrate
from billiard.billiardtables b
join billiard.tabletypes t on b.tabletypeid = t.tabletypeid

insert into billiard.dim_service (service_id, service_name, service_cost)
select serviceid, servicename, servicecost
from billiard.services

insert into billiard.dim_date (date_key, full_date, cal_year, cal_month, cal_day)
select distinct
    cast(convert(varchar(8), d, 112) as int) as date_key,
    d as full_date,
    year(d) as cal_year,
    month(d) as cal_month,
    day(d) as cal_day
from (
    select cast(starttime as date) as d from billiard.sessions
    union
    select cast(endtime as date) from billiard.sessions
    union
    select paymentdate from billiard.payments
) dates
where d is not null

go

insert into billiard.fact_session (session_id, customer_key, table_key, staff_key, start_date_key, end_date_key, total_time_hours, amount_billed)
select
    s.sessionid,
    c.customer_key,
    t.table_key,
    st.staff_key,
    cast(convert(varchar(8), s.starttime, 112) as int) as start_date_key,
    cast(convert(varchar(8), s.endtime, 112) as int) as end_date_key,
    s.totaltimehours,
    s.amountbilled
from billiard.sessions s
join billiard.dim_customer c on s.customerid = c.customer_id
join billiard.dim_billiardtable t on s.tablenumber = t.table_number
join billiard.dim_staff st on s.staffid = st.staff_id

insert into billiard.fact_payment (payment_id, session_key, payment_date_key, payment_amount, payment_status)
select
    p.paymentid,
    fs.session_key,
    cast(convert(varchar(8), p.paymentdate, 112) as int) as payment_date_key,
    p.paymentamount,
    p.paymentstatus
from billiard.payments p
join billiard.fact_session fs on p.sessionid = fs.session_id

insert into billiard.fact_session_service (session_key, service_key, service_cost)
select
    fs.session_key,
    ds.service_key,
    ds.service_cost
from billiard.session_services ss
join billiard.fact_session fs on ss.sessionid = fs.session_id
join billiard.dim_service ds on ss.serviceid = ds.service_id

go

-- Billiard Salon -- 3NF OLTP schema + load from raw CSV
-- RUN ORDER: 1 of 4. Run this first.
-- Source: billiard.[billiard salon management] (flat staging table imported via SSMS Import Flat File).
-- Change-tracking triggers live in bill_timestamps_triggers.sql (run 2).

drop table if exists billiard.session_services
drop table if exists billiard.payments
drop table if exists billiard.sessions
drop table if exists billiard.billiardtables
drop table if exists billiard.tabletypes
drop table if exists billiard.services
drop table if exists billiard.staff
drop table if exists billiard.customers
go

create table billiard.customers (
    customerid int primary key,
    customername varchar(255),
    customeremail varchar(255) unique,
    customerphone varchar(50),
    modifiedon datetime default getdate()
)

create table billiard.staff (
    staffid int primary key,
    staffname varchar(255),
    staffrole varchar(100),
    modifiedon datetime default getdate()
)

create table billiard.tabletypes (
    tabletypeid int primary key,
    typename varchar(50) unique,
    modifiedon datetime default getdate()
)

create table billiard.billiardtables (
    tablenumber int primary key,
    tabletypeid int,
    hourlyrate decimal(10, 2),
    modifiedon datetime default getdate(),
    foreign key (tabletypeid) references billiard.tabletypes(tabletypeid)
)

create table billiard.services (
    serviceid int primary key,
    servicename varchar(100),
    servicecost decimal(10, 2),
    modifiedon datetime default getdate()
)

create table billiard.sessions (
    sessionid int primary key,
    customerid int,
    tablenumber int,
    staffid int,
    starttime datetime,
    endtime datetime,
    totaltimehours float,
    amountbilled decimal(10, 2),
    modifiedon datetime default getdate(),
    foreign key (customerid) references billiard.customers(customerid),
    foreign key (tablenumber) references billiard.billiardtables(tablenumber),
    foreign key (staffid) references billiard.staff(staffid)
)

create table billiard.session_services (
    sessionid int,
    serviceid int,
    modifiedon datetime default getdate(),
    primary key (sessionid, serviceid),
    foreign key (sessionid) references billiard.sessions(sessionid),
    foreign key (serviceid) references billiard.services(serviceid)
)

create table billiard.payments (
    paymentid int primary key,
    sessionid int,
    paymentdate date,
    paymentamount decimal(10, 2),
    paymentstatus varchar(50),
    modifiedon datetime default getdate(),
    foreign key (sessionid) references billiard.sessions(sessionid)
)
go

-- Load normalized tables from the flat staging table, in FK-dependency order.
-- Surrogate keys generated with DENSE_RANK (entities) and ROW_NUMBER (payments).

insert into billiard.customers (customerid, customername, customeremail, customerphone)
select
    dense_rank() over (order by customer_email) as customerid,
    customer_name,
    customer_email,
    customer_phone
from billiard.[billiard salon management]
where customer_email is not null
group by customer_name, customer_email, customer_phone

insert into billiard.staff (staffid, staffname, staffrole)
select
    dense_rank() over (order by staff_name) as staffid,
    staff_name,
    staff_role
from billiard.[billiard salon management]
where staff_name is not null
group by staff_name, staff_role

insert into billiard.tabletypes (tabletypeid, typename)
select
    dense_rank() over (order by table_type) as tabletypeid,
    table_type
from billiard.[billiard salon management]
where table_type is not null
group by table_type

insert into billiard.billiardtables (tablenumber, tabletypeid, hourlyrate)
select distinct
    b.table_number,
    tt.tabletypeid,
    b.hourly_rate
from billiard.[billiard salon management] b
join billiard.tabletypes tt on b.table_type = tt.typename
where b.table_number is not null

insert into billiard.services (serviceid, servicename, servicecost)
select
    dense_rank() over (order by service_name) as serviceid,
    service_name,
    service_cost
from billiard.[billiard salon management]
where service_name is not null
group by service_name, service_cost

insert into billiard.sessions (sessionid, customerid, tablenumber, staffid, starttime, endtime, totaltimehours, amountbilled)
select distinct
    b.session_id,
    c.customerid,
    b.table_number,
    st.staffid,
    cast(b.start_time as datetime) as starttime,
    cast(b.end_time as datetime) as endtime,
    b.[total_time_hours],
    b.amount_billed
from billiard.[billiard salon management] b
join billiard.customers c on b.customer_email = c.customeremail
join billiard.staff st on b.staff_name = st.staffname

insert into billiard.session_services (sessionid, serviceid)
select distinct
    b.session_id,
    s.serviceid
from billiard.[billiard salon management] b
join billiard.services s on b.service_name = s.servicename
where b.service_name is not null

insert into billiard.payments (paymentid, sessionid, paymentdate, paymentamount, paymentstatus)
select
    row_number() over (order by t.session_id, t.payment_date) as paymentid,
    t.session_id,
    cast(t.payment_date as date) as paymentdate,
    t.payment_amount,
    t.payment_status
from (
    select distinct
        session_id,
        payment_date,
        payment_amount,
        payment_status
    from billiard.[billiard salon management]
    where payment_date is not null
) t
go

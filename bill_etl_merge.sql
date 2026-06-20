-- Billiard Salon -- incremental ETL (OLTP -> warehouse)
-- RUN ORDER: 4 of 4. Run after billdimensional.sql.
-- Re-runnable: each MERGE syncs inserts, updates, and deletes.
-- Dimensions use full upsert (WHEN MATCHED / NOT MATCHED BY TARGET / NOT MATCHED BY SOURCE).
-- Facts are insert + delete only (a fact row is never updated).

merge into billiard.dim_customer as target
using (
    select customerid, customername, customeremail, customerphone
    from billiard.customers
) as source
on target.customer_id = source.customerid
when matched then
    update set
        target.customer_name = source.customername,
        target.customer_email = source.customeremail,
        target.customer_phone = source.customerphone
when not matched by target then
    insert (customer_id, customer_name, customer_email, customer_phone)
    values (source.customerid, source.customername, source.customeremail, source.customerphone)
when not matched by source then
    delete;

go

merge into billiard.dim_staff as target
using (
    select staffid, staffname, staffrole
    from billiard.staff
) as source
on target.staff_id = source.staffid
when matched then
    update set
        target.staff_name = source.staffname,
        target.staff_role = source.staffrole
when not matched by target then
    insert (staff_id, staff_name, staff_role)
    values (source.staffid, source.staffname, source.staffrole)
when not matched by source then
    delete;

go

merge into billiard.dim_billiardtable as target
using (
    select b.tablenumber, t.typename, b.hourlyrate
    from billiard.billiardtables b
    join billiard.tabletypes t on b.tabletypeid = t.tabletypeid
) as source
on target.table_number = source.tablenumber
when matched then
    update set
        target.table_type = source.typename,
        target.hourly_rate = source.hourlyrate
when not matched by target then
    insert (table_number, table_type, hourly_rate)
    values (source.tablenumber, source.typename, source.hourlyrate)
when not matched by source then
    delete;

go

merge into billiard.dim_service as target
using (
    select serviceid, servicename, servicecost
    from billiard.services
) as source
on target.service_id = source.serviceid
when matched then
    update set
        target.service_name = source.servicename,
        target.service_cost = source.servicecost
when not matched by target then
    insert (service_id, service_name, service_cost)
    values (source.serviceid, source.servicename, source.servicecost)
when not matched by source then
    delete;

go

merge into billiard.dim_date as target
using (
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
        select cast(paymentdate as date) from billiard.payments
    ) dates
    where d is not null
) as source
on target.date_key = source.date_key
when matched then
    update set
        target.full_date = source.full_date,
        target.cal_year = source.cal_year,
        target.cal_month = source.cal_month,
        target.cal_day = source.cal_day
when not matched by target then
    insert (date_key, full_date, cal_year, cal_month, cal_day)
    values (source.date_key, source.full_date, source.cal_year, source.cal_month, source.cal_day);

go

merge into billiard.fact_session as target
using (
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
) as source
on target.session_id = source.sessionid
when not matched by target then
    insert (session_id, customer_key, table_key, staff_key, start_date_key, end_date_key, total_time_hours, amount_billed)
    values (source.sessionid, source.customer_key, source.table_key, source.staff_key, source.start_date_key, source.end_date_key, source.totaltimehours, source.amountbilled)
when not matched by source then
    delete;

go

merge into billiard.fact_payment as target
using (
    select
        p.paymentid,
        fs.session_key,
        cast(convert(varchar(8), p.paymentdate, 112) as int) as payment_date_key,
        p.paymentamount,
        p.paymentstatus
    from billiard.payments p
    join billiard.fact_session fs on p.sessionid = fs.session_id
) as source
on target.payment_id = source.paymentid
when not matched by target then
    insert (payment_id, session_key, payment_date_key, payment_amount, payment_status)
    values (source.paymentid, source.session_key, source.payment_date_key, source.paymentamount, source.paymentstatus)
when not matched by source then
    delete;

go

merge into billiard.fact_session_service as target
using (
    select
        fs.session_key,
        ds.service_key,
        ds.service_cost
    from billiard.session_services ss
    join billiard.fact_session fs on ss.sessionid = fs.session_id
    join billiard.dim_service ds on ss.serviceid = ds.service_id
) as source
on target.session_key = source.session_key and target.service_key = source.service_key
when not matched by target then
    insert (session_key, service_key, service_cost)
    values (source.session_key, source.service_key, source.service_cost)
when not matched by source then
    delete;

go

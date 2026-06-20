-- Billiard Salon -- change-tracking triggers
-- RUN ORDER: 2 of 4. Run after normalised.sql.
-- AFTER INSERT/UPDATE triggers on the 6 source tables; stamp modifiedon = getdate().
-- The modifiedon columns are defined in normalised.sql.
-- (Recursive trigger firing is off by default in SQL Server, so the trigger's own
--  UPDATE does not re-fire the trigger.)

create or alter trigger billiard.trg_customers_modified
on billiard.customers
after insert, update
as
begin
    update billiard.customers
    set modifiedon = getdate()
    from billiard.customers c
    inner join inserted i on c.customerid = i.customerid
end
go

create or alter trigger billiard.trg_staff_modified
on billiard.staff
after insert, update
as
begin
    update billiard.staff
    set modifiedon = getdate()
    from billiard.staff s
    inner join inserted i on s.staffid = i.staffid
end
go

create or alter trigger billiard.trg_billiardtables_modified
on billiard.billiardtables
after insert, update
as
begin
    update billiard.billiardtables
    set modifiedon = getdate()
    from billiard.billiardtables t
    inner join inserted i on t.tablenumber = i.tablenumber
end
go

create or alter trigger billiard.trg_services_modified
on billiard.services
after insert, update
as
begin
    update billiard.services
    set modifiedon = getdate()
    from billiard.services s
    inner join inserted i on s.serviceid = i.serviceid
end
go

create or alter trigger billiard.trg_sessions_modified
on billiard.sessions
after insert, update
as
begin
    update billiard.sessions
    set modifiedon = getdate()
    from billiard.sessions s
    inner join inserted i on s.sessionid = i.sessionid
end
go

create or alter trigger billiard.trg_payments_modified
on billiard.payments
after insert, update
as
begin
    update billiard.payments
    set modifiedon = getdate()
    from billiard.payments p
    inner join inserted i on p.paymentid = i.paymentid
end
go

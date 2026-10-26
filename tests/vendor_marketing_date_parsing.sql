select 'bad_vendor_date_parsing' as failure
where {{ drugs_vendor_date("'20240328'") }}<>cast('2024-03-28' as date)
 or {{ drugs_vendor_date("'2024-03-28'") }}<>cast('2024-03-28' as date)
 or {{ drugs_vendor_date("'bad_date'") }} is not null
 or {{ drugs_vendor_date("'20240231'") }} is not null

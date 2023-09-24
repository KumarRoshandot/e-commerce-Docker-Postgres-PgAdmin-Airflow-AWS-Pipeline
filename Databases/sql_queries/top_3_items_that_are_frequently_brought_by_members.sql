select
	d.item_name,
	sum(f.quantity) as total_quantity
from tb_f_sales_transactions f join tb_d_items d
on f.item_id = d.item_id
where f.status = 'completed'
group by d.item_name
order by sum(f.quantity) desc
limit 3;
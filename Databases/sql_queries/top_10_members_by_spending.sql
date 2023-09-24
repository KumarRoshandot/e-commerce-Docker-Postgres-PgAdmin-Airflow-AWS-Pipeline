select
	d.first_name||' '||d.last_name as member_name,
	sum(f.item_total_price) as total_spending
from tb_f_sales_transactions f join tb_d_user_applications d
on f.membership_id = d.membership_id
group by d.first_name||' '||d.last_name
order by sum(f.item_total_price) desc
limit 10;
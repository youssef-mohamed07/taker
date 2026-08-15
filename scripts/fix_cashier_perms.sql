-- One-time fix: reset cashier (user 2) permissions to role defaults.
UPDATE permissions SET can_view = 0, can_create = 0, can_edit = 0, can_delete = 0 WHERE user_id = 2;
UPDATE permissions SET can_view = 1 WHERE user_id = 2 AND module IN ('dashboard','pos','sales-history','customers','returns','shifts');
UPDATE permissions SET can_create = 1 WHERE user_id = 2 AND module IN ('pos','customers','returns');

namespace LFinance {
	internal class Account {
		internal string _name {internal get; private set;}
		internal uint _sorting {internal get; private set;}
		internal Gee.List<Expense> _expenses {internal get; private set;}

		bool sharp;
		unowned TriggerFunc func;

		internal Account(string name) {
			this._name = name;
			this._expenses = new Gee.ArrayList<Expense>();
			this.sharp = false;
			this.func = null;
		}
		internal void set_name(string name) {
			this._name = name;
			this.fire (TriggerType.EDIT_ACCOUNT);
		}
		internal Account sorted_copy() {
			var copy = new Account (this._name);
			foreach(var expense in this._expenses)
				copy._expenses.add (expense);
			copy._sorting = 3; // Ascending date
			copy.sort (false);
			return copy;
		}
		internal void set_sorting(uint sorting) {
			this._sorting = sorting;
			this.sort (false);
			this.fire (TriggerType.EDIT_ACCOUNT);
		}
		internal void add_expense(Expense expense) {
			this._expenses.add (expense);
			expense.sort ();
			expense.set_sharp (this.func);
			this.sort (false);
			this.fire (TriggerType.ADD_EXPENSE);
			this.fire (TriggerType.EDIT_ACCOUNT);
		}
		internal void fire(TriggerType type) {
			if((!this.sharp) || this.func == null) {
				return;
			}
			this.func (type);
		}
		internal void delete_expense(Expense expense) {
			this._expenses.remove (expense);
			this.fire (TriggerType.DELETE_EXPENSE);
			this.fire (TriggerType.EDIT_ACCOUNT);
		}

		internal void set_sharp(TriggerFunc func) {
			this.func = func;
			this.sharp = true;
			this._expenses.foreach(a => {
				a.set_sharp (func);
				return true;
			});
		}
		internal void sort(bool sort_expenses = true) {
			this._expenses.sort ((a, b) => {
				switch(this._sorting) {
				case 1:
					return a._amount > b._amount ? 1 : (a._amount == b._amount ? 0 : -1);
				case 2:
					return a._purpose.collate (b._purpose);
				case 3:
					return a._date.compare (b._date);
				case 4:
					return a._amount > b._amount ? -1 : (a._amount == b._amount ? 0 : 1);
				case 5:
					return b._purpose.collate (a._purpose);
				case 6:
					return b._date.compare (a._date);
				}
				return 0;
			});
			if(sort_expenses) {
				this._expenses.foreach(a => {
					a.sort ();
					return true;
				});
			}
			this.fire (TriggerType.ACCOUNT_EXPENSES_SORT);
		}
		internal Gee.List<Expense> expenses_after(DateTime date) {
			var ret = new Gee.ArrayList<Expense>();
			foreach(var expense in this._expenses) {
				if(expense._date.compare (date) >= 0) {
					ret.add (expense);
				}
			}
			return ret;
		}
		internal Json.Node serialize() {
			var builder = new Json.Builder ();
			builder.begin_object ();
			builder.set_member_name ("name");
			builder.add_string_value (this._name);
			builder.set_member_name ("sorting");
			builder.add_int_value (this._sorting);
			builder.set_member_name ("expenses");
			builder.begin_array ();
			foreach(var expense in this._expenses) {
				builder.add_value (expense.serialize ());
			}
			builder.end_array ();
			builder.end_object ();
			return builder.get_root ();
		}
		internal void fill_sample_data(Gee.List<Tag> tags, Gee.List<Location> locations, bool small) {
			this.sharp = false;
			var now = new DateTime.now();
			var start_month = Random.next_int() % 4 + 5;
			var start_day = (int) (Random.next_int() % 28) + 1;
			var start_year = now.get_year() - (Random.next_int() % (small ? 10 : 100));
			var date = new DateTime.utc((int)start_year, (int)start_month, start_day, 0, 0, 0);
			if(date == null) {
				Posix.perror("date.utc");
			}
			info("%u %u %d", start_year, start_month, start_day);
			assert(date != null);
			while(true) {
				date = date.add_days((int)(Random.next_int() % 4));
				if(date.compare(now) > 0)
					break;
				this.add_expense(this.random_expense(date));
			}
			this.set_sorting(3);
			this.sharp = true;
		}
		internal void fill_holiday_data(int year, Gee.List<Tag> tags, Gee.List<Location> locations, bool small) {
			this.sharp = false;
			var start_month = 5;
			var start_day = (int) (Random.next_int() % 27) + 1;
			var date = new DateTime.utc(year, start_month, start_day, 0, 0, 0);
			if(date == null) {
				Posix.perror("DateTime.utc");
			}
			assert(date != null);
			this.add_expense(this.new_expense(_("Vacation apartment"), date, Random.next_double() * 1500));
			var n = Random.next_int() % (small ? 40 : 500) + 8;
			for (var i = 0; i < n; i++) {
				date = date.add_days((int)(Random.next_int() % 4));
				this.add_expense(this.random_expense(date));
			}
			this.set_sorting(3);
			this.sharp = true;
		}
		Expense new_expense(string purpose, DateTime date, double amount) {
			var irounded = (int32)(amount * 100);
			var ret = new Expense(purpose);
			ret.set_currency("€");
			ret.set_date(date);
			ret.set_amount(irounded);
			return ret;
		}
		Expense random_expense(DateTime date, uint remainder = 5) {
			var ret = new Expense("");
			ret.set_date(date);
			ret.set_currency("€");
			switch(Random.next_int() % remainder) {
				case 0: // Culture
					ret.set_amount(Random.next_int() % 3000);
					ret.set_purpose(this.random_string(_("Cinema"), _("Opera"), _("Theatre"), _("Museum")));
					break;
				case 1: // Restaurant
					ret.set_amount(Random.next_int() % 9000 + 3000);
					ret.set_purpose(this.random_string(_("Dürüm"), _("Pizza"), _("Greek food"), _("Burger"), _("Chinese food"), _("Indian food")));
					break;
				case 2: // Groceries
					ret.set_amount(Random.next_int() % 6000 + 200);
					ret.set_purpose(this.random_string(_("Lunch"), _("Groceries"), _("Bakery ingredients"), _("Regular grocery shopping")));
					break;
				case 3: // Fuel
					ret.set_amount(Random.next_int() % 9000);
					ret.set_purpose(_("%.2lf litres gasoline").printf(Random.next_double() * 80 + 20));
					break;
				case 4: // Hobbies
					ret.set_amount(Random.next_int() % 29000);
					ret.set_purpose(this.random_string(_("Soccer match tickets"), _("Paraglider course"), _("Diving with dolphins"), _("Zoo")));
					break;
			}
			return ret;
		}
		string random_string(...) {
			var l = va_list();
			string? hot_str = l.arg();
			while(true) {
				var rand = Random.next_double();
				if(rand < 0.5)
					return hot_str;
				string? tmp = l.arg();
				if(tmp == null)
					return hot_str;
				hot_str = tmp;

			}
		}
	}
}

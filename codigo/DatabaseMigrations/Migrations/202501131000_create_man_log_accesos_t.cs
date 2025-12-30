using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501131000)]
	public class _202501131000_create_man_log_accesos_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_log_accesos_t.sql");
		}

		public override void Down()
		{
		}
	}
}

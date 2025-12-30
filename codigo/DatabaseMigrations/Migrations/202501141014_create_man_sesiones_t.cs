using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141014)]
	public class _202501141014_create_man_sesiones_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_sesiones_t.sql");
		}

		public override void Down()
		{
		}
	}
}

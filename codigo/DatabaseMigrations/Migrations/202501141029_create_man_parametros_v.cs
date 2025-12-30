using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141029)]
	public class _202501141029_create_man_parametros_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_parametros_v.sql");
		}

		public override void Down()
		{
		}
	}
}

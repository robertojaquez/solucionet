using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141013)]
	public class _202501141013_create_man_parametros_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_parametros_t.sql");
		}

		public override void Down()
		{
		}
	}
}

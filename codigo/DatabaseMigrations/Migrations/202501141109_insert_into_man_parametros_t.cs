using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141109)]
	public class _202501141109_insert_into_man_parametros_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("insert_into_man_parametros_t.sql");
		}

		public override void Down()
		{
		}
	}
}

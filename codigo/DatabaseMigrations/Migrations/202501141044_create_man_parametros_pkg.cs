using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141044)]
	public class _202501141044_create_man_parametros_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_parametros_spec_pkg.sql");
			Execute.Script("man_parametros_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

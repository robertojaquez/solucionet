using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141030)]
	public class _202501141030_create_man_formatear_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_formatear_spec_pkg.sql");
			Execute.Script("man_formatear_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

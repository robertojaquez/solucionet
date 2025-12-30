using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141043)]
	public class _202501141043_create_man_mantenimientos_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_mantenimientos_spec_pkg.sql");
			Execute.Script("man_mantenimientos_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

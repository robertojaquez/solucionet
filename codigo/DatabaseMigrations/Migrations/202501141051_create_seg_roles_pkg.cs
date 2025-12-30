using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141051)]
	public class _202501141051_create_seg_roles_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_roles_spec_pkg.sql");
			Execute.Script("seg_roles_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

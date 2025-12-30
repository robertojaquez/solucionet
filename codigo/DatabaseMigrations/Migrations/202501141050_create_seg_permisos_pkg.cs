using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141050)]
	public class _202501141050_create_seg_permisos_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_permisos_spec_pkg.sql");
			Execute.Script("seg_permisos_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

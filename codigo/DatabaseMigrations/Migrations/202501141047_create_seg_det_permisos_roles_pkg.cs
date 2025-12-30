using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141047)]
	public class _202501141047_create_seg_det_permisos_roles_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_det_permisos_roles_spec_pkg.sql");
			Execute.Script("seg_det_permisos_roles_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

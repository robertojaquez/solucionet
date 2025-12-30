using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141048)]
	public class _202501141048_create_seg_det_roles_usuarios_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_det_roles_usuarios_spec_pkg.sql");
			Execute.Script("seg_det_roles_usuarios_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

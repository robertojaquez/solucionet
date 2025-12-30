using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141035)]
	public class _202501141035_create_seg_det_roles_usuarios_mchk_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_det_roles_usuarios_mchk_v.sql");
		}

		public override void Down()
		{
		}
	}
}

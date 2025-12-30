using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141037)]
	public class _202501141037_create_seg_det_roles_usuarios_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_det_roles_usuarios_v.sql");
		}

		public override void Down()
		{
		}
	}
}

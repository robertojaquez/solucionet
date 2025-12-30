using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141018)]
	public class _202501141018_create_seg_det_roles_usuarios_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_det_roles_usuarios_t.sql");
		}

		public override void Down()
		{
		}
	}
}

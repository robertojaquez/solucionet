using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141017)]
	public class _202501141017_create_seg_det_permisos_roles_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_det_permisos_roles_t.sql");
		}

		public override void Down()
		{
		}
	}
}

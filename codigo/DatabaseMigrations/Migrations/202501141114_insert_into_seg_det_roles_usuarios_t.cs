using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141114)]
	public class _202501141114_insert_into_seg_det_roles_usuarios_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("insert_into_seg_det_roles_usuarios_t.sql");
		}

		public override void Down()
		{
		}
	}
}

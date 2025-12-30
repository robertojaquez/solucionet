using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141034)]
	public class _202501141034_create_seg_det_permisos_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_det_permisos_v.sql");
		}

		public override void Down()
		{
		}
	}
}

using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141039)]
	public class _202501141039_create_seg_permisos_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_permisos_v.sql");
		}

		public override void Down()
		{
		}
	}
}

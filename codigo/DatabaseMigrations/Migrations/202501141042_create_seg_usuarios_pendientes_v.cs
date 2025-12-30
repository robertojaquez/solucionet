using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141042)]
	public class _202501141042_create_seg_usuarios_pendientes_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_usuarios_pendientes_v.sql");
		}

		public override void Down()
		{
		}
	}
}

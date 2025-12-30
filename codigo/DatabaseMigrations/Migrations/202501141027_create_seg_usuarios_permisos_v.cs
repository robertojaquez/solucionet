using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141027)]
	public class _202501141027_create_seg_usuarios_permisos_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_usuarios_permisos_v.sql");
		}

		public override void Down()
		{
		}
	}
}

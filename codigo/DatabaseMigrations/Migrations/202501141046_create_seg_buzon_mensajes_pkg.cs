using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141046)]
	public class _202501141046_create_seg_buzon_mensajes_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_buzon_mensajes_spec_pkg.sql");
			Execute.Script("seg_buzon_mensajes_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

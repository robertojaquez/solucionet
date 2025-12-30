using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141032)]
	public class _202501141032_create_seg_buzon_mensajes_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_buzon_mensajes_v.sql");
		}

		public override void Down()
		{
		}
	}
}

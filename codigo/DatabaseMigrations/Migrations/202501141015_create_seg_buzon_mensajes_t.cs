using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141015)]
	public class _202501141015_create_seg_buzon_mensajes_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_buzon_mensajes_t.sql");
		}

		public override void Down()
		{
		}
	}
}

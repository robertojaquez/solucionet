using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141006)]
	public class _202501141006_create_man_det_bandas_reportes_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_det_bandas_reportes_t.sql");
		}

		public override void Down()
		{
		}
	}
}

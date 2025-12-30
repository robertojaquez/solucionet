using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141010)]
	public class _202501141010_create_man_det_trazabilidad_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_det_trazabilidad_t.sql");
		}

		public override void Down()
		{
		}
	}
}

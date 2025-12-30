using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141009)]
	public class _202501141009_create_man_trazabilidad_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_trazabilidad_t.sql");
		}

		public override void Down()
		{
		}
	}
}

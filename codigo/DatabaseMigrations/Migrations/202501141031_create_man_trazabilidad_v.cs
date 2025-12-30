using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141031)]
	public class _202501141031_create_man_trazabilidad_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_trazabilidad_v.sql");
		}

		public override void Down()
		{
		}
	}
}

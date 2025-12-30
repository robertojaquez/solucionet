using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141005)]
	public class _202501141005_create_man_reportes_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_reportes_t.sql");
		}

		public override void Down()
		{
		}
	}
}

using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141011)]
	public class _202501141011_create_man_excepciones_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_excepciones_t.sql");
		}

		public override void Down()
		{
		}
	}
}

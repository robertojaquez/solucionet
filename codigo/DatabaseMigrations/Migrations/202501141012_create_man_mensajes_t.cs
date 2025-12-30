using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141012)]
	public class _202501141012_create_man_mensajes_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_mensajes_t.sql");
		}

		public override void Down()
		{
		}
	}
}

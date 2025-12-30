using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141115)]
	public class _202501141115_grants_usuario_app : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("grants_usuario_app.sql");
		}

		public override void Down()
		{
		}
	}
}

using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141026)]
	public class _202501141026_create_sms_mensajes_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("sms_mensajes_t.sql");
		}

		public override void Down()
		{
		}
	}
}

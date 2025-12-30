using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141021)]
	public class _202501141021_create_html_mail_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("html_mail_t.sql");
		}

		public override void Down()
		{
		}
	}
}

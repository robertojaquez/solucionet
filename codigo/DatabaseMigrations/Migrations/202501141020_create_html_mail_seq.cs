using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141020)]
	public class _202501141020_create_html_mail_seq : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("html_mail_seq.sql");
		}

		public override void Down()
		{
		}
	}
}

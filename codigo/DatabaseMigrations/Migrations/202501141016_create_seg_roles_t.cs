using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141016)]
	public class _202501141016_create_seg_roles_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_roles_t.sql");
		}

		public override void Down()
		{
		}
	}
}

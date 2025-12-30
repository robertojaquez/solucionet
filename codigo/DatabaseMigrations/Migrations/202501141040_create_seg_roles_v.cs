using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141040)]
	public class _202501141040_create_seg_roles_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_roles_v.sql");
		}

		public override void Down()
		{
		}
	}
}

using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141019)]
	public class _202501141019_create_seg_usuarios_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_usuarios_v.sql");
		}

		public override void Down()
		{
		}
	}
}

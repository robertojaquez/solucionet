using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141041)]
	public class _202501141041_create_seg_usuarios_menues_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_usuarios_menues_v.sql");
		}

		public override void Down()
		{
		}
	}
}

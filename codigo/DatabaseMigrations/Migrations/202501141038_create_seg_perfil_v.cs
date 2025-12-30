using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141038)]
	public class _202501141038_create_seg_perfil_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_perfil_v.sql");
		}

		public override void Down()
		{
		}
	}
}

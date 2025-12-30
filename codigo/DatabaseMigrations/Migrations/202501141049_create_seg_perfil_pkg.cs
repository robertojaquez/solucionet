using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141049)]
	public class _202501141049_create_seg_perfil_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_perfil_spec_pkg.sql");
			Execute.Script("seg_perfil_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

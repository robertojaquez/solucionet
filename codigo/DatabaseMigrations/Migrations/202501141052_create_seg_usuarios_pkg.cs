using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141052)]
	public class _202501141052_create_seg_usuarios_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_usuarios_spec_pkg.sql");
			Execute.Script("seg_usuarios_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

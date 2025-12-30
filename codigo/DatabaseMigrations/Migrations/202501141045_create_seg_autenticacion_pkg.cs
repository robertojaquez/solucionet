using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141045)]
	public class _202501141045_create_seg_autenticacion_pkg : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("seg_autenticacion_spec_pkg.sql");
			Execute.Script("seg_autenticacion_body_pkg.sql");
		}

		public override void Down()
		{
		}
	}
}

using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141106)]
	public class _202501141106_insert_into_seg_secciones_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("insert_into_seg_secciones_t.sql");
		}

		public override void Down()
		{
		}
	}
}

using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141007)]
	public class _202501141007_create_man_det_columnas_paginas_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_det_columnas_paginas_t.sql");
		}

		public override void Down()
		{
		}
	}
}

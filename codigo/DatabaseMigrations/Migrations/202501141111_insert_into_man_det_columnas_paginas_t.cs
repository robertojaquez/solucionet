using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141111)]
	public class _202501141111_insert_into_man_det_columnas_paginas_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("insert_into_man_det_columnas_paginas_t.sql");
		}

		public override void Down()
		{
		}
	}
}
